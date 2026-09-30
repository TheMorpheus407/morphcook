#!/usr/bin/env python3
"""Configurable build-time generation, deterministic gates, human review.

Running this tool is a maintainer action. No part of it ships in the app.
"""
import argparse
import copy
import datetime
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'tools'))
from validate_corpus import (ValidationError, calculate_nutrition, near_duplicate,
                             read, validate_corpus, validate_recipe)

STAGES = [('generator','generator'),('verifier','flag-verifier'),
          ('nutrition','nutrition'),('editor','copy-editor'),('reviewer','reviewer')]

def parser():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--dish', required=True)
    p.add_argument('--variants', default='classic,vegan')
    p.add_argument('--agent', required=True, help='claude[:model], codex[:model], opencode/model, or command:...')
    for stage,_ in STAGES[1:]: p.add_argument('--agent-'+stage)
    p.add_argument('--max-retries',type=int,default=3)
    p.add_argument('--sample',type=int,default=5)
    p.add_argument('--dry-run',action='store_true',help='Validate shipped corpus and print the plan; make no agent calls')
    p.add_argument('--commit',action='store_true',help='Prompt for human approval, then update bundled assets; never runs git')
    return p

def agent_command(spec, output):
    if spec.startswith('command:'): return shlex.split(spec.removeprefix('command:'))
    if spec.startswith('opencode/'):
        return ['opencode','run','--model',spec.removeprefix('opencode/'),'--format','json']
    name,_,model=spec.partition(':')
    if name=='claude':
        command=['claude','-p']
        if model: command+=['--model',model]
        return command
    if name=='codex':
        command=['codex','exec','--skip-git-repo-check','--sandbox','read-only','-o',str(output)]
        if model: command+=['--model',model]
        return command+['-']
    raise ValueError(f'Unknown agent {spec!r}; use command: for a custom CLI adapter')

def extract_json(text, depth=0):
    # Adapters may emit fences or progress lines. Decode only a valid JSON value.
    if depth>8: raise ValidationError('Agent output nesting is too deep')
    def payload(value):
        if isinstance(value,list):
            if value and all(isinstance(r,dict) and 'dish_id' in r for r in value): return value
            for item in value:
                result=payload(item)
                if result is not None: return result
        if isinstance(value,dict):
            if any(key in value for key in ('recipes','approved','dish_id')): return value
            # Some CLI adapters stream JSON events containing a text part.
            for key in ('part','text','content','output','result'):
                item=value.get(key)
                if isinstance(item,str):
                    try: return extract_json(item,depth+1)
                    except ValidationError: pass
                elif isinstance(item,(dict,list)):
                    result=payload(item)
                    if result is not None: return result
        return None
    candidates=[text.strip()]
    if '```' in text:
        candidates += [part.removeprefix('json').strip() for part in text.split('```')[1::2]]
    decoder=json.JSONDecoder()
    for candidate in candidates:
        try:
            value=json.loads(candidate)
            result=payload(value)
            if result is not None: return result
        except json.JSONDecodeError: pass
    for position,char in enumerate(text):
        if char in '{[':
            try:
                value,_=decoder.raw_decode(text[position:])
                result=payload(value)
                if result is not None: return result
            except json.JSONDecodeError: pass
    raise ValidationError('Agent output did not contain recipe JSON')

def run_agent(spec, stage, payload, folder):
    prompt=(ROOT/'pipeline/agents'/f'{stage}.md').read_text()+'\n\nINPUT DATA:\n'+json.dumps(payload,ensure_ascii=False)
    (folder/f'{stage}-prompt.txt').write_text(prompt)
    output=folder/f'{stage}-output.txt'
    command=agent_command(spec,output)
    environment=dict(os.environ)
    for key in ('CLAUDECODE','CLAUDE_CODE_CHILD_SESSION','CLAUDE_CODE_SESSION_ID',
                'CLAUDE_CODE_MESSAGING_SOCKET','CLAUDE_CODE_MESSAGING_TOKEN'):
        environment.pop(key,None)
    result=subprocess.run(command,input=prompt,text=True,capture_output=True,cwd=ROOT,env=environment)
    if not output.exists(): output.write_text(result.stdout)
    (folder/f'{stage}-stderr.txt').write_text(result.stderr)
    if result.returncode: raise ValidationError(f'{stage} agent exited with code {result.returncode}; see {folder}')
    return extract_json(output.read_text())

def recipe_output(output, previous=None):
    if isinstance(output,dict) and output.get('approved') is False:
        raise ValidationError(str(output.get('feedback','Reviewer rejected recipe')))
    if isinstance(output,list):
        if not output or not all(isinstance(r,dict) for r in output):
            raise ValidationError('Agent must return at least one complete recipe')
        return output
    if isinstance(output,dict):
        if 'recipes' in output: return recipe_output(output['recipes'])
        if 'dish_id' in output: return [output]
        if output.get('approved') is True and previous is not None: return previous
    raise ValidationError('Agent must return {"recipes": [...]} or reviewer approval')

def reindex(recipes):
    """Update canonical corpus and every affected asset atomically per file."""
    assets=ROOT/'app/assets'
    dishes=read('dishes.json'); manifest=read('partition-manifest.json')
    lookup={d['id']:d for d in dishes}; dictionary={i['id']:i for i in read('ingredients.json')}
    ontology=read('ontology.json')
    for dish in dishes: dish['variant_recipe_ids']=[r['id'] for r in recipes if r['dish_id']==dish['id']]
    def write(name,data):
        target=assets/name; temporary=target.with_suffix(target.suffix+'.pending')
        temporary.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n'); temporary.replace(target)
    write('recipes.json',recipes); write('dishes.json',dishes)
    for key,partition in manifest['partitions'].items():
        if key in ('core','extended'): items=[r for r in recipes if lookup[r['dish_id']]['partition_id']==key]
        else: items=[r for r in recipes if key.removeprefix('cuisine-') in r['tags']]
        write(partition['file'],items); partition['recipe_ids']=[r['id'] for r in items]
        partition['dish_ids']=sorted({r['dish_id'] for r in items})
    manifest['corpus_version']=datetime.datetime.now(datetime.timezone.utc).strftime('%Y.%m.%d')
    write('partition-manifest.json',manifest)
    index=[]
    for recipe in recipes:
        dish=lookup[recipe['dish_id']]
        text={lang:' '.join([recipe['title'][lang],dish['canonical_name'][lang],recipe['description'][lang],
            *[dictionary[i['id']]['name'][lang] for i in recipe['ingredients']],
            *[ontology['tag_labels'].get(tag,{}).get(lang,tag) for tag in recipe['tags']]]) for lang in ('en','de')}
        index.append({'id':recipe['id'],'partition_id':dish['partition_id'],'tags':recipe['tags'],'text':text})
    write('search-index.json',index)

def main(argv=None):
    args=parser().parse_args(argv)
    dishes={d['id']:d for d in read('dishes.json')}
    if args.dish not in dishes: raise SystemExit(f'Unknown dish {args.dish}')
    if args.max_retries<0 or args.sample<1: raise SystemExit('Retries must be non-negative; sample must be positive')
    variants=[v.strip() for v in args.variants.split(',') if v.strip()]
    if not variants or any(v not in read('ontology.json')['diets'] for v in variants): raise SystemExit('Unknown or empty variants')
    agents={stage:getattr(args,'agent_'+stage,None) or args.agent for stage,_ in STAGES}
    for spec in agents.values(): agent_command(spec,ROOT/'pipeline/.runs/output.txt')
    if args.dry_run:
        validate_corpus()
        print(json.dumps({'dish':args.dish,'variants':variants,'agents':agents,
                          'max_retries':args.max_retries,'writes':False,'agent_calls':0},indent=2))
        return 0
    timestamp=datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    folder=ROOT/'pipeline/.runs'/timestamp; folder.mkdir(parents=True)
    ontology=read('ontology.json'); dictionary={i['id']:i for i in read('ingredients.json')}
    existing=read('recipes.json'); generated=[]
    for variant in variants:
        feedback=''
        for attempt in range(args.max_retries+1):
            run=folder/f'{variant}-{attempt}';run.mkdir()
            payload={'dish':dishes[args.dish],'variant':variant,'ontology':ontology,
                     'ingredients':list(dictionary.values()),'feedback':feedback,'recipe_schema':json.loads((ROOT/'pipeline/schemas/recipe.schema.json').read_text())}
            try:
                recipes=recipe_output(run_agent(agents['generator'],'generator',payload,run))
                for stage,prompt in STAGES[1:]:
                    payload['recipes']=recipes
                    recipes=recipe_output(run_agent(agents[stage],prompt,payload,run),recipes)
                    if stage=='verifier':
                        for recipe in recipes:
                            # Nutritional accuracy is computed before the final gate.
                            recipe['macros'],recipe['calories_per_serving']=calculate_nutrition(recipe,dictionary)
                            validate_recipe(recipe,ontology,dictionary,dishes)
                    if stage=='nutrition':
                        for recipe in recipes: recipe['macros'],recipe['calories_per_serving']=calculate_nutrition(recipe,dictionary)
                for recipe in recipes:
                    validate_recipe(recipe,ontology,dictionary,dishes)
                    if recipe['dish_id']!=args.dish or recipe['dimensions']['diet']!=variant:
                        raise ValidationError('Agent returned an unexpected dish or variant')
                    for other in existing+generated:
                        if other['id']!=recipe['id'] and near_duplicate(recipe,other): raise ValidationError('Near duplicate of '+other['id'])
                generated.extend(recipes);break
            except (ValidationError,KeyError,TypeError) as error:
                feedback=str(error);(run/'rejection.txt').write_text(feedback)
                if attempt==args.max_retries: raise SystemExit(f'{variant} exhausted its retries: {feedback}')
    (folder/'recipes.json').write_text(json.dumps(generated,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(generated[:args.sample],ensure_ascii=False,indent=2))
    print(f'Human review sample: {min(args.sample,len(generated))} of {len(generated)} recipes. Full output: {folder}')
    if args.commit:
        if not sys.stdin.isatty(): raise SystemExit('Human approval requires an interactive terminal. Generated output has been retained.')
        if input('After reviewing the sample and full output, type APPROVE to update bundled assets: ')!='APPROVE':
            print('Bundled assets unchanged.');return 0
        merged={r['id']:r for r in existing}; merged.update({r['id']:r for r in generated})
        reindex(list(merged.values()));validate_corpus()
        (folder/'human-approval.json').write_text(json.dumps({'approved_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'recipes':[r['id'] for r in generated]},indent=2))
    return 0

if __name__=='__main__': raise SystemExit(main())
