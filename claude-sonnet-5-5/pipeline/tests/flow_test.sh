#!/usr/bin/env bash
# The five stages end to end with a stub agent: the happy path, every way a
# variant is sent back, the human spot-check and the commit.
source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"

staged_file() { printf '%s/work/porridge/candidates.json' "$TMP"; }
recipe_ids() { python3 -c 'import json,sys; print(" ".join(r["id"] for r in json.load(open(sys.argv[1]))["recipes"]))' "$1"; }
field_of() { python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); r=[x for x in d["recipes"] if x["id"]==sys.argv[2]][0]; print(json.dumps(r[sys.argv[3]], ensure_ascii=False))' "$1" "$2" "$3"; }

t_happy_path() {
  happy_replies
  pipeline --dish porridge --variants vegan --agent "$(stub_agent main)"
  assert_status "the run" 0
  assert_eq "the five stages run once, in order" \
    "generator flag-verifier nutrition copy-editor reviewer" "$(calls | awk '{print $1}' | paste -sd' ')"
  assert_contains "the recipe is staged" "$OUT" "staged    porridge-vegan"
  assert_eq "only the staged file holds the recipe" "porridge-vegan" "$(recipe_ids "$(staged_file)")"
  assert_eq "the nutrition agent's calories are in" "460" "$(field_of "$(staged_file)" porridge-vegan calories_per_serving)"
  assert_contains "the copy editor's wording is in" "$(field_of "$(staged_file)" porridge-vegan blurb)" "crowned with toasted walnuts"
  assert_contains "derived fields were filled in" "$(field_of "$(staged_file)" porridge-vegan contains)" "gluten"
  assert_contains "the human spot-check prints English" "$OUT" "Vegan Porridge  [porridge-vegan]"
  assert_contains "the human spot-check prints German" "$OUT" "Veganer Haferbrei  [porridge-vegan]"
  assert_contains "the next step is named" "$OUT" "./pipeline.sh --dish porridge --commit"
  assert_eq "the corpus is untouched until the commit" "porridge-classic" \
    "$(python3 -c 'import json,sys; print(" ".join(r["id"] for r in json.load(open(sys.argv[1]))["recipes"]))' "$TMP/assets/recipes.json")"
}

t_prompts_carry_the_facts_each_stage_needs() {
  happy_replies
  pipeline --dish porridge --variants vegan --agent "$(stub_agent main)"
  local generator verifier nutrition copy reviewer
  generator=$(prompt_of generator 1)
  verifier=$(prompt_of flag-verifier 1)
  nutrition=$(prompt_of nutrition 1)
  copy=$(prompt_of copy-editor 1)
  reviewer=$(prompt_of reviewer 1)
  assert_contains "generator: the instructions" "$generator" "You write one recipe for MorphCook"
  assert_contains "generator: the target id" "$generator" "recipe with the id \`porridge-vegan\`"
  assert_contains "generator: the sibling variants" "$generator" "porridge-classic"
  assert_contains "generator: the ingredient dictionary" "$generator" "rolled-oats [gluten]"
  assert_contains "generator: the vocabulary" "$generator" '"techniques"'
  # shellcheck disable=SC2016  # the schema's own $id keys, not shell variables
  assert_contains "generator: the reply schema" "$generator" '"$id":"https://morphcook.app/schemas/recipe.schema.json"'
  assert_not_contains "generator: no previous draft in round one" "$generator" "Your previous draft"
  assert_contains "verifier: what each ingredient brings" "$verifier" '"oat-milk"'
  assert_contains "verifier: the diet promise" "$verifier" "\`vegan\` promises"
  assert_contains "nutrition: weights in grams" "$nutrition" '"grams":80'
  assert_contains "nutrition: the servings" "$nutrition" "2 servings"
  assert_contains "copy editor: the recipe" "$copy" '"id": "porridge-vegan"'
  assert_contains "reviewer: the similar variants" "$reviewer" "Most similar variants"
  assert_contains "reviewer: says the gates passed" "$reviewer" "Every automatic quality gate has passed"
}

t_commit_merges_and_rebuilds() {
  happy_replies
  pipeline --dish porridge --variants vegan --agent "$(stub_agent main)"
  pipeline --dish porridge --commit --dry-run
  assert_status "commit --dry-run" 0
  assert_contains "the dry run says what it would do" "$OUT" "would merge 1 recipes (1 new, 0 replaced)"
  assert_eq "the dry run writes nothing" "porridge-classic" \
    "$(python3 -c 'import json,sys; print(" ".join(r["id"] for r in json.load(open(sys.argv[1]))["recipes"]))' "$TMP/assets/recipes.json")"
  assert_file "and keeps the staged file" "$(staged_file)"

  pipeline --dish porridge --commit
  assert_status "commit" 0
  assert_contains "reports the merge" "$OUT" "merged 1 recipes (1 new, 0 replaced)"
  assert_eq "recipes.json holds both variants, grouped by dish" "porridge-classic porridge-vegan" \
    "$(python3 -c 'import json,sys; print(" ".join(r["id"] for r in json.load(open(sys.argv[1]))["recipes"]))' "$TMP/assets/recipes.json")"
  assert_eq "the dish lists the new recipe" "porridge-classic porridge-vegan" \
    "$(python3 -c 'import json,sys; print(" ".join(json.load(open(sys.argv[1]))["dishes"][0]["recipes"]))' "$TMP/assets/dishes.json")"
  assert_contains "the core partition holds the new recipe" "$(cat "$TMP/assets/core-recipes.json")" "porridge-vegan"
  assert_file "the search index is rebuilt" "$TMP/assets/search/core.json"
  assert_no_file "the work folder is removed" "$TMP/work/porridge"
  local checked
  checked=$(cd -- "$APP_DIR" && dart tool/corpus_tool.dart check --assets "$TMP/assets" 2>&1)
  assert_contains "the merged corpus passes the app's own check" "$checked" "0 errors, 0 warnings"
}

t_keep_work() {
  happy_replies
  pipeline --dish porridge --variants vegan --agent "$(stub_agent main)"
  pipeline --dish porridge --commit --keep-work
  assert_status "commit --keep-work" 0
  assert_file "the staged file stays" "$(staged_file)"
}

t_discard() {
  happy_replies
  pipeline --dish porridge --variants vegan --agent "$(stub_agent main)"
  assert_file "staged" "$(staged_file)"
  pipeline --dish porridge --discard
  assert_status "discard" 0
  assert_no_file "the work folder is gone" "$TMP/work/porridge"
}

t_flag_verifier_rejects_once() {
  happy_replies
  reply flag-verifier.1 verifier-reject.reply
  reply flag-verifier.2 verifier-approve.reply
  pipeline --dish porridge --variants vegan --agent "$(stub_agent main)"
  assert_status "the run" 0
  assert_eq "the generator ran twice" "2" "$(count_of generator)"
  assert_eq "the verifier ran twice" "2" "$(count_of flag-verifier)"
  local second
  second=$(prompt_of generator 2)
  assert_contains "the second round carries the feedback" "$second" "Feedback from the previous attempt"
  assert_contains "with the verifier's words" "$second" "The walnuts are toasted in butter"
  assert_contains "and the issue kind and place" "$second" "[hidden-ingredient] steps[1]"
  assert_contains "and the previous draft to revise" "$second" "Your previous draft"
  assert_contains "the recipe is staged in the end" "$OUT" "staged    porridge-vegan"
}

t_reviewer_rejects_until_the_retries_run_out() {
  happy_replies
  reply reviewer reviewer-reject.reply
  pipeline --dish porridge --variants vegan --agent "$(stub_agent main)" --max-retries 1
  assert_status "a variant is given up" 1
  assert_eq "one retry means two rounds" "2" "$(count_of generator)"
  assert_contains "the reviewer's issue reached the generator" "$(prompt_of generator 2)" "stir until the oats are soft"
  assert_contains "the output says so" "$OUT" "given up  porridge-vegan (after 2 rounds"
  assert_no_file "nothing is staged" "$(staged_file)"
  assert_file "the log is kept for the maintainer" "$TMP/work/porridge/vegan.log"
  assert_contains "the log holds the replies" "$(cat "$TMP/work/porridge/vegan.log")" "reviewer: reply"
  assert_not_contains "no spot-check without staged recipes" "$OUT" "Human spot-check"
}

t_max_retries_zero_means_a_single_round() {
  happy_replies
  reply flag-verifier verifier-reject.reply
  pipeline --dish porridge --variants vegan --agent "$(stub_agent main)" --max-retries 0
  assert_status "given up after one round" 1
  assert_eq "one generator call" "1" "$(count_of generator)"
}

t_prose_instead_of_json() {
  happy_replies
  reply generator.1 generator-prose.reply
  pipeline --dish porridge --variants vegan --agent "$(stub_agent main)"
  assert_status "the run" 0
  assert_eq "the generator is asked again" "2" "$(count_of generator)"
  assert_contains "with the reason" "$(prompt_of generator 2)" "The reply contains no JSON object"
}

t_the_contains_gate_names_the_missing_flags() {
  happy_replies
  reply generator.1 generator-bad-contains.reply
  pipeline --dish porridge --variants vegan --agent "$(stub_agent main)"
  assert_status "the run" 0
  assert_eq "the verifier only sees the recipe once the gates pass" "1" "$(count_of flag-verifier)"
  assert_contains "the gate report goes back to the generator" "$(prompt_of generator 2)" "contains lacks flags the ingredients bring"
  assert_contains "and names the flags" "$(prompt_of generator 2)" "gluten"
}

t_bad_nutrition_goes_back_to_the_same_agent() {
  happy_replies
  reply nutrition.1 nutrition-bad.reply
  pipeline --dish porridge --variants vegan --agent "$(stub_agent main)"
  assert_status "the run" 0
  assert_eq "the nutrition agent is asked twice" "2" "$(count_of nutrition)"
  assert_eq "the generator only once" "1" "$(count_of generator)"
  assert_contains "the feedback names the arithmetic" "$(prompt_of nutrition 2)" "The macros add up to"
}

t_copy_editor_may_only_change_wording() {
  happy_replies
  reply copy-editor.1 copy-editor-bad.reply
  pipeline --dish porridge --variants vegan --agent "$(stub_agent main)"
  assert_status "the run" 0
  assert_eq "the copy editor is asked twice" "2" "$(count_of copy-editor)"
  assert_eq "the generator only once" "1" "$(count_of generator)"
  assert_contains "the guard names the changed field" "$(prompt_of copy-editor 2)" '"time_minutes" was changed, but only wording may change'
  assert_eq "the numbers stayed as the recipe had them" "15" "$(field_of "$(staged_file)" porridge-vegan time_minutes)"
}

t_a_copy_editor_that_never_complies_sends_the_recipe_back() {
  happy_replies
  reply copy-editor copy-editor-bad.reply
  pipeline --dish porridge --variants vegan --agent "$(stub_agent main)" --max-retries 1
  assert_status "given up" 1
  assert_contains "the generator hears about it" "$(prompt_of generator 2)" "The copy-editor could not deliver"
}

t_agents_are_chosen_per_stage() {
  happy_replies
  pipeline --dish porridge --variants vegan --agent "$(stub_agent main)" --agent-verifier "$(stub_agent checker)" \
    --agent-nutrition "$(stub_agent numbers)" --agent-reviewer "$(stub_agent boss)"
  assert_status "the run" 0
  assert_eq "each stage reached its own agent" \
    "generator main flag-verifier checker nutrition numbers copy-editor main reviewer boss" \
    "$(calls | awk '{print $1, $2}' | paste -sd' ')"
}

t_a_failing_agent_is_a_failed_round() {
  happy_replies
  rm -f "$TMP/replies/reviewer.reply"
  pipeline --dish porridge --variants vegan --agent "$(stub_agent main)" --max-retries 0
  assert_status "given up" 1
  assert_contains "the log names the agent failure" "$(cat "$TMP/work/porridge/vegan.log")" "reviewer: agent failure"
}

t_a_slow_agent_runs_into_the_timeout() {
  happy_replies
  export STUB_SLEEP=5
  pipeline --dish porridge --variants vegan --agent "$(stub_agent main)" --max-retries 0 --timeout 1
  assert_status "given up" 1
  assert_contains "the timeout is named" "$(cat "$TMP/work/porridge/vegan.log")" "ran past the 1s limit"
  unset STUB_SLEEP
}

t_several_variants_are_independent() {
  happy_replies
  # The second variant's recipe id does not match what the stub returns, so it is sent back every time.
  pipeline --dish porridge --variants vegan,keto --agent "$(stub_agent main)" --max-retries 0
  assert_status "one variant fails" 1
  assert_contains "the first is staged" "$OUT" "staged    porridge-vegan"
  assert_contains "the second is given up" "$OUT" "given up  porridge-keto"
  assert_contains "the reason is the id" "$(cat "$TMP/work/porridge/keto.log")" 'expected "porridge-keto"'
  assert_eq "the staged file holds the one that passed" "porridge-vegan" "$(recipe_ids "$(staged_file)")"
}

t_a_new_dish_from_a_spec() {
  happy_replies
  pipeline --dish porridge --variants vegan --agent "$(stub_agent main)" --dish-spec "$FIXTURES/dish-spec.json"
  assert_status "the run" 0
  assert_contains "the generator prompt describes the dish" "$(prompt_of generator 1)" '"partition_id": "core"'
  pipeline --dish porridge --commit --dish-spec "$FIXTURES/dish-spec.json"
  assert_status "commit" 0
  assert_eq "the dish is in dishes.json with its recipe" "porridge:porridge-vegan" \
    "$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1]))["dishes"][0]; print(d["id"]+":"+",".join(d["recipes"]))' "$TMP/assets/dishes.json")"
  local checked
  checked=$(cd -- "$APP_DIR" && dart tool/corpus_tool.dart check --assets "$TMP/assets" 2>&1)
  assert_contains "the corpus passes the app's own check" "$checked" "0 errors, 0 warnings"
}

t_a_new_dish_without_a_spec_stops_before_any_agent_runs() {
  happy_replies
  pipeline --dish porridge --variants vegan --agent "$(stub_agent main)"
  assert_status "the run" 66
  assert_eq "no agent was called" "" "$(calls)"
}

t_sample_can_be_switched_off() {
  happy_replies
  pipeline --dish porridge --variants vegan --agent "$(stub_agent main)" --sample 0
  assert_status "the run" 0
  assert_not_contains "no spot-check printed" "$OUT" "Human spot-check"
}

t_a_missing_agent_program_stops_the_run_early() {
  happy_replies
  pipeline --dish porridge --variants vegan --agent "cmd:$TMP/not-there"
  assert_status "the run" 69
  assert_contains "the message names the agent" "$OUT" "is not available on this machine"
}

run t_happy_path "happy path"
run t_prompts_carry_the_facts_each_stage_needs "each stage gets the facts it needs"
run t_commit_merges_and_rebuilds "commit merges the staged recipes and rebuilds the partitions"
run t_keep_work "commit --keep-work"
run t_discard "discard"
run t_flag_verifier_rejects_once "the flag verifier rejects once"
run t_reviewer_rejects_until_the_retries_run_out "the reviewer rejects until the retries run out"
run t_max_retries_zero_means_a_single_round "--max-retries 0"
run t_prose_instead_of_json "a reply without JSON"
run t_the_contains_gate_names_the_missing_flags "the contains gate"
run t_bad_nutrition_goes_back_to_the_same_agent "nutrition that does not add up"
run t_copy_editor_may_only_change_wording "the copy editor may only change wording"
run t_a_copy_editor_that_never_complies_sends_the_recipe_back "a copy editor that never complies"
run t_agents_are_chosen_per_stage "agents are chosen per stage"
run t_a_failing_agent_is_a_failed_round "a failing agent"
run t_a_slow_agent_runs_into_the_timeout "a slow agent"
run t_several_variants_are_independent "several variants are independent"
run t_a_new_dish_from_a_spec "a new dish from a spec" empty
run t_a_new_dish_without_a_spec_stops_before_any_agent_runs "a new dish without a spec" empty
run t_sample_can_be_switched_off "--sample 0"
run t_a_missing_agent_program_stops_the_run_early "a missing agent program"
finish
