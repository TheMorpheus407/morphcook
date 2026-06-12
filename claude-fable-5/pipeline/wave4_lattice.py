#!/usr/bin/env python3
"""Wave-4 lattice pipeline — codex writes, codex reviews, loop until it passes.

Rebuilds every dish around the actual USP: one dish, a complete lattice of
fully-authored recipes (diet × effort × calorie), per docs/corpus-brief-4.md.

For each dish:
  1. PLAN    codex drafts the dish plan (columns, pairs, cells, legacy map,
             coverage) → mechanical validation (validate_corpus.py) → a second
             codex reviews → on rejection the feedback loops back to the
             writer until it passes.
  2. CELLS   one recipe per lattice cell, written by codex, mechanically
             validated, then reviewed by a second codex — same feedback loop.
             Sequential within a dish so each author sees accepted siblings.
  3. DISH    cells merged, dish-level validation (lattice completeness,
             title uniqueness, soul-rule coverage), then one codex reviews
             the whole set and may bounce individual cells back to step 2.
  4. MERGE   when EVERY dish passes: recipes are written back into the app
             asset partitions, dishes.json is relinked, the partition
             manifest gets corpus_wave=4 (arming the app-side contract
             tests) and a version bump.

Everything is resumable — state is plain files under pipeline/wave4/; rerun
the same command and it picks up where it stopped. To redo one dish:
  ./wave4_lattice.py --reset-dish <id>   (then rerun)

Beyond the base lattice:

  GROW       --new-dish "okonomiyaki": codex researches the baseline
             (canonical spelling EN/DE, hero/caption, routing, missing
             catalog ingredients with allergen flags — reviewed, the flag
             audit is the safety gate), then the dish's full lattice is
             generated and merged. --suggest-dish N: codex invents N dishes
             itself (baseline only, queued; the next run writes their
             recipes — a queued dish never ships without its lattice).
  COVER      --expand-coverage: for every lattice cell, fully-authored
             variants for what people can't eat — free of gluten, dairy,
             nuts, … then pairs ("no gluten AND no dairy"), then triples.
             Cells already fine (a vegan cell is already dairy-free) are
             skipped; genuinely impossible ones are recorded and never
             retried. The longer it runs, the deeper the combination space.
  FOREVER    --forever: cycle = finish lattices → merge → one coverage
             combination → scout one new dish → repeat, until interrupted
             or --call-budget runs out. Fully resumable at any point.

Typical runs:
  ./wave4_lattice.py                      # the whole corpus, 4 dishes in parallel
  ./wave4_lattice.py --jobs 8             # more parallel dishes
  ./wave4_lattice.py --dishes doener,burger
  ./wave4_lattice.py --new-dish "pad see ew"
  ./wave4_lattice.py --suggest-dish 3    # queue three codex-invented dishes
  ./wave4_lattice.py --expand-coverage --max-combo-size 2
  ./wave4_lattice.py --forever --jobs 8  # let it run; ctrl-c is safe
  ./wave4_lattice.py --status            # progress overview, no codex calls
  ./wave4_lattice.py --merge-only        # just the merge (all dishes done)
  ./wave4_lattice.py --self-test         # machinery checks, no codex calls

Codex runs with `--sandbox read-only` (it never writes; this script owns all
file writes) and `--ephemeral`. Model defaults to your codex config; override
with --model / --review-model.
"""
import argparse
import functools
import json
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from datetime import date
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
REPO = SCRIPT_DIR.parent
ASSETS = REPO / "app" / "assets"
AGENTS = SCRIPT_DIR / "agents"
VALIDATOR = SCRIPT_DIR / "validate_corpus.py"
WORK = SCRIPT_DIR / "wave4"

EFFORTS = ["easy", "medium", "hard"]
CAL_BUCKETS = ["le400", "le600", "le800", "gt800"]
CAL_SHORT = {"le400": "400", "le600": "600", "le800": "800", "gt800": "900"}
EXTRA_DIETS = ("gluten-free", "low-fodmap")
NUT_FLAGS = {"peanuts", "tree-nuts", "almonds", "walnuts", "cashews",
             "hazelnuts", "pistachios", "pine-nuts"}
COVERAGE_PROFILES = ["vegan", "vegetarian", "halal", "kosher",
                     "gluten", "dairy", "egg", "nuts", "soy"]
# Avoid-groups for the coverage expansion, ordered by real-world prevalence.
# The expansion walks singles first, then pairs, then triples … — the longer
# it runs, the deeper into the combination space it gets. Meat/fish classes
# are deliberately absent: those are the diet axis's business.
COVERAGE_GROUPS = [
    ("gluten", frozenset({"gluten"})),
    ("dairy", frozenset({"dairy"})),
    ("nuts", frozenset(NUT_FLAGS)),
    ("egg", frozenset({"egg"})),
    ("soy", frozenset({"soy"})),
    ("sesame", frozenset({"sesame"})),
    ("fodmap", frozenset({"high-fodmap"})),
    ("sugar", frozenset({"added-sugar"})),
    ("mustard", frozenset({"mustard"})),
    ("celery", frozenset({"celery"})),
    ("shellfish", frozenset({"shellfish", "molluscs"})),
    ("fish", frozenset({"fish"})),
    ("alcohol", frozenset({"alcohol"})),
    ("honey", frozenset({"honey"})),
    ("caffeine", frozenset({"caffeine"})),
    ("sulphites", frozenset({"sulphites"})),
    ("lupin", frozenset({"lupin"})),
]
FREQUENCY_TIERS = {"high", "medium", "low"}

EN_BANNED = [
    (re.compile(r"\binstead of\b", re.I), '"instead of" framing'),
    (re.compile(r"\breplaces\b", re.I), '"replaces" framing'),
    (re.compile(r"\bfools everyone\b", re.I), '"fools everyone"'),
    (re.compile(r"\bno \w[\w ]{0,20}, no problem\b", re.I), '"no X, no problem"'),
    (re.compile(r"\bwhere the \w[\w ]{0,30} used to be\b", re.I),
     '"where the X used to be"'),
    (re.compile(r"\bnobody will\b", re.I), '"nobody will …" trope'),
    (re.compile(r"\bsimply\b", re.I), '"simply"'),
    (re.compile(r"\bdelicious\b", re.I), '"delicious"'),
]
DE_BANNED = [
    (re.compile(r"pulsieren", re.I), 'Anglizismus "pulsieren"'),
    (re.compile(r"pfannenrühren", re.I), 'Anglizismus "pfannenrühren"'),
    (re.compile(r"häcksel", re.I), 'Anglizismus "häckseln"'),
]

_print_lock = threading.Lock()
_budget_lock = threading.Lock()
_calls_made = 0
# Distinguishes log files of separate runs (the call counter restarts).
RUN_STAMP = time.strftime("%m%d-%H%M%S")


class PipelineError(Exception):
    """A dish (or stage) failed after exhausting its attempts."""


class CodexUnavailable(PipelineError):
    """Infrastructure failure (CLI errors, timeouts, unparseable reviewer
    output) — retryable, never evidence that content is impossible."""


class BudgetExceeded(Exception):
    pass


def log(dish, msg):
    with _print_lock:
        print(f"[{dish}] {msg}", flush=True)


def read_json(path):
    return json.loads(Path(path).read_text())


def write_json(path, data):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")


# ---------------------------------------------------------------- contexts

class Ctx:
    """Loaded assets + prompt building blocks, shared across threads."""

    def __init__(self):
        self.ontology = read_json(ASSETS / "ontology.json")
        shipped = read_json(ASSETS / "dishes.json")["dishes"]
        pending_path = WORK / "pending-dishes.json"
        self.pending = read_json(pending_path) if pending_path.exists() \
            else []
        # Self-heal a crash window between "shipped into dishes.json" and
        # "cleared from pending" — a dish must never appear twice.
        shipped_ids = {d["id"] for d in shipped}
        if any(d["id"] in shipped_ids for d in self.pending):
            self.pending = [d for d in self.pending
                            if d["id"] not in shipped_ids]
            write_json(pending_path, self.pending)
        # Pending dishes (scouted but not yet shipped) take part in every
        # stage; the merge moves them into dishes.json once their lattice
        # exists, so the app never ships an empty dish.
        self.dishes = shipped + self.pending
        self.dish_by_id = {d["id"]: d for d in self.dishes}
        self.manifest = read_json(ASSETS / "partition-manifest.json")
        self.compounds = {c["id"]: c["expands_to"]
                          for c in self.ontology["compound_flags"]}
        self.techniques = self.ontology["attributes"]["technique"]
        self.profile_avoid = {
            "vegan": set(self.compounds["vegan"]),
            "vegetarian": set(self.compounds["vegetarian"]),
            "halal": set(self.compounds["halal"]),
            "kosher": set(self.compounds["kosher"]),
            "gluten": {"gluten"}, "dairy": {"dairy"}, "egg": {"egg"},
            "nuts": set(NUT_FLAGS), "soy": {"soy"},
        }
        self.ing_flags = {}
        self.catalog = self._build_catalog()
        self.prompts = {name: (AGENTS / f"lattice-{name}.md").read_text()
                        for name in ("planner", "plan-reviewer", "writer",
                                     "recipe-reviewer", "dish-reviewer",
                                     "dish-scout", "scout-reviewer")}

    def _build_catalog(self):
        lines = []
        ing = read_json(ASSETS / "ingredients.json")

        def walk(node, parents, inherited):
            flags = sorted(set(node.get("flags") or []) | inherited)
            self.ing_flags[node["id"]] = set(flags)
            name = node.get("name", {})
            path = ">".join(parents) if parents else "(top level)"
            lines.append(
                f"{node['id']} ({path}) | {name.get('en', '?')} / "
                f"{name.get('de', '?')} | "
                f"{', '.join(flags) if flags else 'no flags'}")
            for child in node.get("children", []):
                walk(child, parents + [node["id"]], set(flags))

        for root in ing["nodes"]:
            walk(root, [], set())
        return "\n".join(lines)

    def profile_avoid_text(self):
        return "\n".join(f"- {p}: {', '.join(sorted(s))}"
                         for p, s in self.profile_avoid.items())

    def compound_text(self):
        out = [f"- {cid}: avoid-set = {', '.join(exp)}"
               for cid, exp in self.compounds.items()]
        out.append("- gluten-free: applies iff `gluten` not in contains")
        return "\n".join(out)

    def contains_flags_text(self):
        return ", ".join(f["id"] for f in self.ontology["contains_flags"])

    def partitions_text(self):
        return "\n".join(f"- {p['id']}: {p.get('description', '')}"
                         for p in self.manifest["partitions"])

    def existing_dishes_text(self):
        return "\n".join(
            f"- {d['id']} | {d['name'].get('en', '?')} | "
            f"{', '.join(d.get('cuisine_tags', [])) or 'no tags'} | "
            f"{d.get('partition_id')} | {d.get('frequency_tier')}"
            for d in self.dishes)

    def column_avoid(self, diet):
        return {"vegan": set(self.compounds["vegan"]),
                "vegetarian": set(self.compounds["vegetarian"]),
                "gluten-free": {"gluten"},
                "low-fodmap": {"high-fodmap"}}.get(diet, set())


def fill(template, slots):
    text = template
    for key, value in slots.items():
        text = text.replace("{{" + key + "}}", value)
    leftover = re.findall(r"\{\{[A-Z_]+\}\}", text)
    if leftover:
        raise RuntimeError(f"unfilled prompt slots: {leftover}")
    return text


def feedback_block(latest, older=(), prev=None):
    """Feedback section for a retry prompt.

    `prev` (the last parsed attempt) turns retries into in-place revisions —
    without it the model rewrites from scratch and oscillates between
    complaints. `older` keeps earlier rounds' objections visible so fixed
    defects don't get reintroduced.
    """
    parts = []
    if prev is not None:
        parts.append("## Your previous attempt\n\nRevise it in place — keep "
                     "everything that was not flagged.\n\n"
                     + json.dumps(prev, ensure_ascii=False, indent=2))
    if latest:
        parts.append("## Feedback on your previous attempt — fix ALL of "
                     "it\n\n" + "\n".join(f"- {i}" for i in latest))
    if older:
        parts.append("## Raised on earlier attempts — do not reintroduce\n\n"
                     + "\n".join(f"- {i}" for i in older))
    return "\n\n".join(parts) + ("\n" if parts else "")


# ------------------------------------------------------------------- codex

def codex_call(args, prompt, dish, label):
    """One codex exec invocation. Returns the agent's final message text."""
    global _calls_made
    with _budget_lock:
        if args.call_budget and _calls_made >= args.call_budget:
            raise BudgetExceeded(f"--call-budget {args.call_budget} reached")
        _calls_made += 1
        seq = _calls_made

    log_dir = WORK / "logs" / dish
    log_dir.mkdir(parents=True, exist_ok=True)
    log_path = log_dir / f"{RUN_STAMP}-{seq:04d}-{label}.md"

    last_err = ""
    for attempt in range(1, 4):
        with tempfile.NamedTemporaryFile("r", suffix=".txt",
                                         delete=False) as out:
            out_path = Path(out.name)
        cmd = [args.codex_cmd, "exec", "--sandbox", "read-only",
               "--ephemeral", "--color", "never", "--skip-git-repo-check",
               "--output-last-message", str(out_path)]
        model = (args.review_model if "review" in label and args.review_model
                 else args.model)
        if model:
            cmd += ["-m", model]
        cmd.append("-")
        try:
            proc = subprocess.run(cmd, input=prompt, text=True, cwd=REPO,
                                  capture_output=True,
                                  timeout=args.call_timeout)
            reply = out_path.read_text().strip()
            if proc.returncode == 0 and reply:
                log_path.write_text(
                    f"# {label} (attempt {attempt})\n\n{prompt}\n\n"
                    f"----- RESPONSE -----\n\n{reply}\n")
                return reply
            last_err = (f"exit {proc.returncode}; "
                        f"stderr tail: {proc.stderr[-400:]}")
        except subprocess.TimeoutExpired:
            last_err = f"timed out after {args.call_timeout}s"
        finally:
            out_path.unlink(missing_ok=True)
        log(dish, f"codex {label} attempt {attempt} failed ({last_err}); "
                  "retrying")
        time.sleep(15 * attempt)
    raise CodexUnavailable(f"codex call {label} failed 3 times: {last_err}")


def extract_json(text):
    """Parse an agent reply into one JSON object.

    Returns (obj, None) on success, (None, reason) on failure. A brace-scan
    candidate is accepted only when it spans essentially the whole reply —
    a small embedded fragment parsing cleanly means the reply itself was
    broken JSON (e.g. a bad escape), and feeding the fragment onward would
    produce nonsense feedback instead of the actual parse error.
    """
    text = text.strip()
    candidates = [text]
    fence = re.search(r"```(?:json)?\s*(.*?)```", text, re.S)
    if fence:
        candidates.insert(0, fence.group(1).strip())
    parse_err = None
    for cand in candidates:
        try:
            return json.loads(cand), None
        except (json.JSONDecodeError, ValueError) as exc:
            parse_err = parse_err or str(exc)
    start = text.find("{")
    while 0 <= start <= 200:
        depth, in_str, esc = 0, False, False
        for i in range(start, len(text)):
            ch = text[i]
            if in_str:
                if esc:
                    esc = False
                elif ch == "\\":
                    esc = True
                elif ch == '"':
                    in_str = False
            elif ch == '"':
                in_str = True
            elif ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
                if depth == 0:
                    if len(text) - (i + 1) <= 200:
                        try:
                            return json.loads(text[start:i + 1]), None
                        except (json.JSONDecodeError, ValueError):
                            pass
                    break
        if text.startswith("{"):
            # The reply was meant to be one object and it is broken —
            # salvaging an inner fragment would only mislead the loop.
            break
        start = text.find("{", start + 1)
    return None, parse_err or "no JSON object found"


def run_validator(*vargs):
    proc = subprocess.run(
        [sys.executable, str(VALIDATOR), "--ctx", str(ASSETS), "--json",
         *[str(a) for a in vargs]],
        capture_output=True, text=True)
    try:
        report = json.loads(proc.stdout)
    except json.JSONDecodeError:
        raise PipelineError(
            f"validator crashed: {proc.stderr[-600:] or proc.stdout[-600:]}")
    return report["errors"], report["warnings"]


def validate_tmp(payload, *vargs):
    """Write payload to a temp file and validate with it as first arg."""
    with tempfile.NamedTemporaryFile("w", suffix=".json",
                                     delete=False) as tmp:
        json.dump(payload, tmp, ensure_ascii=False)
        tmp_path = Path(tmp.name)
    try:
        return run_validator(vargs[0], tmp_path, *vargs[1:])
    finally:
        tmp_path.unlink(missing_ok=True)


# ------------------------------------------------------------------ stages

def snapshot_current(ctx):
    """Freeze the pre-wave-4 corpus once, per dish (legacy-map ground truth).

    Built in a temp dir and renamed atomically, so an interrupted first run
    can never leave a partial snapshot that later runs trust. Dishes added
    to dishes.json after the freeze get their snapshot filled in on the next
    run (empty when the shipped corpus has no recipes for them yet) — adding
    a dish is one dishes.json entry plus a pipeline run.
    """
    current_dir = WORK / "current"
    if current_dir.exists():
        missing = [d["id"] for d in ctx.dishes
                   if not (current_dir / f"{d['id']}.json").exists()]
        if missing:
            by_dish = {dish_id: [] for dish_id in missing}
            for part in ctx.manifest["partitions"]:
                for recipe in read_json(REPO / "app" /
                                        part["file"])["recipes"]:
                    if recipe["dish_id"] in by_dish:
                        by_dish[recipe["dish_id"]].append(recipe)
            for dish_id, recipes in by_dish.items():
                write_json(current_dir / f"{dish_id}.json",
                           {"dish_id": dish_id, "recipes": recipes})
                print(f"snapshot added for new dish {dish_id} "
                      f"({len(recipes)} existing recipes)")
        return
    tmp_dir = WORK / "current.tmp"
    if tmp_dir.exists():
        shutil.rmtree(tmp_dir)
    by_dish = {d["id"]: [] for d in ctx.dishes}
    for part in ctx.manifest["partitions"]:
        for recipe in read_json(REPO / "app" / part["file"])["recipes"]:
            by_dish[recipe["dish_id"]].append(recipe)
    for dish_id, recipes in by_dish.items():
        write_json(tmp_dir / f"{dish_id}.json",
                   {"dish_id": dish_id, "recipes": recipes})
    tmp_dir.rename(current_dir)


def plan_slots(ctx, dish):
    current = read_json(WORK / "current" / f"{dish['id']}.json")
    return {
        "DISH_JSON": json.dumps(dish, ensure_ascii=False, indent=2),
        "CURRENT_RECIPES_JSON": json.dumps(current["recipes"],
                                           ensure_ascii=False, indent=2),
        "INGREDIENT_CATALOG": ctx.catalog,
        "PROFILE_AVOID_SETS": ctx.profile_avoid_text(),
        "CONTAINS_FLAGS": ctx.contains_flags_text(),
    }


def as_feedback(fn):
    """Any crash while checking a model reply becomes feedback, never a
    dish-killing exception — the loop exists to absorb model sloppiness."""
    @functools.wraps(fn)
    def wrapped(*fargs, **fkwargs):
        try:
            return fn(*fargs, **fkwargs)
        except Exception as exc:  # noqa: BLE001 — by design
            note = (f"your reply could not be processed "
                    f"({type(exc).__name__}: {str(exc)[:300]}) — emit "
                    "exactly the documented JSON shape")
            return ([note], []) if fn.__name__ == "mech_recipe_check" \
                else [note]
    return wrapped


@as_feedback
def mech_plan_errors(ctx, dish_id, plan):
    if not isinstance(plan, dict):
        return ["reply was not a JSON object"]
    if plan.get("dish_id") != dish_id:
        return [f"dish_id must be '{dish_id}', got '{plan.get('dish_id')}'"]
    errors, _ = validate_tmp(plan, "--plan", "--current", WORK / "current")
    cells = plan.get("cells", []) + plan.get("extras", [])
    ids = {c.get("recipe_id") for c in cells}
    legacy_ids = {r["id"] for r in read_json(
        WORK / "current" / f"{dish_id}.json")["recipes"]}
    for cell in cells:
        rid = cell.get("recipe_id", "")
        if rid in legacy_ids:
            continue
        want = (f"{dish_id}-{cell.get('diet')}-{cell.get('effort')}-"
                f"{CAL_SHORT.get(cell.get('calorie'), '?')}")
        if rid != want:
            errors.append(f"new cell id '{rid}' must be '{want}' "
                          "(legacy ids may keep their name only when reused)")
    known_flags = {f["id"] for f in ctx.ontology["contains_flags"]}
    for cell in cells:
        unknown = set(cell.get("must_avoid", [])) - known_flags
        if unknown:
            errors.append(f"cell {cell.get('recipe_id')}: unknown must_avoid "
                          f"flags {sorted(unknown)}")
    coverage = plan.get("coverage", {})
    exceptions = {e.get("profile") for e in plan.get("exceptions", [])}
    for profile in COVERAGE_PROFILES:
        if profile in exceptions:
            continue
        target = coverage.get(profile)
        if not target:
            errors.append(f"coverage missing for profile '{profile}' "
                          "(name a cell or declare an exception)")
        elif target not in ids:
            errors.append(f"coverage[{profile}] = '{target}' is not a "
                          "planned cell/extra")
    for profile in set(coverage) | exceptions:
        if profile not in COVERAGE_PROFILES:
            errors.append(f"unknown coverage/exception profile '{profile}'")
    return errors


def effective_must_avoid(ctx, plan):
    """cell id -> flag set, from explicit must_avoid + coverage duties."""
    out = {c["recipe_id"]: set(c.get("must_avoid", []))
           for c in plan.get("cells", []) + plan.get("extras", [])}
    for profile, rid in plan.get("coverage", {}).items():
        if rid in out:
            out[rid] |= ctx.profile_avoid.get(profile, set())
    return out


def plan_stage(args, ctx, dish):
    dish_id = dish["id"]
    path = WORK / "plans" / f"{dish_id}.json"
    if path.exists():
        return read_json(path)
    slots = plan_slots(ctx, dish)
    latest, older, prev = [], [], None

    def bounce(items):
        nonlocal latest, older
        older = [n for n in older + latest if n not in items][-10:]
        latest = items

    for attempt in range(1, args.max_attempts + 1):
        log(dish_id, f"plan: writing (attempt {attempt})")
        reply = codex_call(args, fill(ctx.prompts["planner"],
                                      {**slots,
                                       "FEEDBACK": feedback_block(
                                           latest, older, prev)}),
                           dish_id, f"plan-write-{attempt}")
        plan, parse_err = extract_json(reply)
        if plan is None:
            bounce([f"your reply was not parseable JSON ({parse_err}) — "
                    "output exactly one JSON object, nothing else"])
            continue
        prev = plan
        errors = mech_plan_errors(ctx, dish_id, plan)
        if errors:
            log(dish_id, f"plan: {len(errors)} mechanical error(s)")
            bounce(errors)
            continue
        verdict = review_call(args, ctx, dish_id, "plan-reviewer",
                              {**slots,
                               "PLAN_JSON": json.dumps(plan,
                                                       ensure_ascii=False,
                                                       indent=2)},
                              f"plan-review-{attempt}")
        if verdict.get("approved") is True:
            write_json(path, plan)
            log(dish_id, f"plan: accepted (attempt {attempt})")
            return plan
        bounce([verdict.get("feedback") or "reviewer rejected the plan"])
        log(dish_id, "plan: reviewer bounced")
    raise PipelineError(f"{dish_id}: plan not accepted after "
                        f"{args.max_attempts} attempts")


def review_call(args, ctx, dish_id, prompt_name, slots, label):
    """Reviewer call with strict-JSON retry; never silently approves."""
    for attempt in range(2):
        reply = codex_call(args, fill(ctx.prompts[prompt_name], slots),
                           dish_id, f"{label}{'-retry' if attempt else ''}")
        verdict, _ = extract_json(reply)
        if isinstance(verdict, dict) and "approved" in verdict:
            return verdict
    raise CodexUnavailable(f"{dish_id}: {prompt_name} returned unparseable "
                           "verdicts twice")


def ordered_cells(plan):
    diets = plan.get("diets", []) + [None]  # None bucket = extras at the end

    def key(cell):
        diet = cell["diet"]
        diet_ix = (diets.index(diet) if diet in diets
                   else len(diets) + EXTRA_DIETS.index(diet)
                   if diet in EXTRA_DIETS else 99)
        return (diet_ix, EFFORTS.index(cell["effort"]),
                CAL_BUCKETS.index(cell["calorie"]))

    return sorted(plan.get("cells", []) + plan.get("extras", []), key=key)


def sibling_summary(recipes):
    if not recipes:
        return "none yet — you are writing the first cell of this dish."
    lines = []
    for r in recipes:
        mains = ", ".join(i["ingredient_id"] for i in r["ingredients"][:5])
        lines.append(
            f"- {r['id']} [{r['variant']['diet']}/{r['variant']['effort']}/"
            f"{r['variant']['calorie']}] \"{r['title']['en']}\" / "
            f"\"{r['title']['de']}\" — caption \"{r['caption']['en']}\" — "
            f"{r['calories_per_serving']} kcal, {r['time_minutes']} min — "
            f"mains: {mains}")
    return "\n".join(lines)


def text_lint(recipe):
    """Brief-3 phrase bans the validator doesn't cover."""
    errors = []
    en_parts = [recipe.get("title", {}).get("en", ""),
                recipe.get("caption", {}).get("en", ""),
                recipe.get("intro", {}).get("en", "")]
    en_parts += [s.get("text", {}).get("en", "")
                 for s in recipe.get("steps", [])]
    de_parts = [recipe.get("title", {}).get("de", ""),
                recipe.get("caption", {}).get("de", ""),
                recipe.get("intro", {}).get("de", "")]
    de_parts += [s.get("text", {}).get("de", "")
                 for s in recipe.get("steps", [])]
    for rx, name in EN_BANNED:
        if any(rx.search(p) for p in en_parts):
            errors.append(f"EN text uses banned {name}")
    for rx, name in DE_BANNED:
        if any(rx.search(p) for p in de_parts):
            errors.append(f"DE text uses banned {name}")
    title = recipe.get("title", {})
    if title.get("en", "") != title.get("en", "").lower():
        errors.append("EN title must be lowercase")
    de_title = title.get("de", "")
    if de_title and not de_title[0].isupper():
        errors.append("DE title must start with a capital letter")
    return errors


@as_feedback
def mech_recipe_check(ctx, dish_id, plan_path, cell, recipe, siblings,
                      must_avoid):
    if not isinstance(recipe, dict):
        return ["reply was not a JSON object"], []
    errors, warnings = validate_tmp({"dish_id": dish_id,
                                     "recipes": [recipe]},
                                    "--column", "--plan-file", plan_path)
    if recipe.get("id") != cell["recipe_id"]:
        errors.append(f"id must be '{cell['recipe_id']}', "
                      f"got '{recipe.get('id')}'")
    clash = set(recipe.get("contains", [])) & must_avoid
    if clash:
        errors.append(f"this cell must avoid {sorted(must_avoid)} but the "
                      f"recipe contains {sorted(clash)} — rebuild without "
                      "those (coverage duty, non-negotiable)")
    for sib in siblings:
        for lang in ("en", "de"):
            try:
                if (recipe["title"][lang].strip().lower()
                        == sib["title"][lang].strip().lower()):
                    errors.append(
                        f"title[{lang}] duplicates sibling {sib['id']}")
                if (recipe["caption"][lang].strip().lower()
                        == sib["caption"][lang].strip().lower()):
                    errors.append(
                        f"caption[{lang}] duplicates sibling {sib['id']}")
            except (KeyError, TypeError, AttributeError):
                continue  # malformed fields already flagged by the validator
    errors.extend(text_lint(recipe))
    return errors, warnings


def cell_stage(args, ctx, dish, plan, cell, siblings, initial_feedback=None,
               mode_notes=""):
    dish_id = dish["id"]
    rid = cell["recipe_id"]
    path = WORK / "recipes" / dish_id / f"{rid}.json"
    if path.exists():
        return read_json(path)
    plan_path = WORK / "plans" / f"{dish_id}.json"
    must_avoid = set(cell.get("must_avoid", [])) \
        | effective_must_avoid(ctx, plan).get(rid, set())
    cell_doc = {**cell, "must_avoid": sorted(must_avoid)}
    legacy = next((r for r in read_json(
        WORK / "current" / f"{dish_id}.json")["recipes"] if r["id"] == rid),
        None)
    legacy_block = ""
    if legacy:
        legacy_block = (
            "## Legacy recipe to adapt — keep the id and the good prose; "
            "fix the title, the coordinates, the buckets and anything the "
            "rules above demand\n\n"
            + json.dumps(legacy, ensure_ascii=False, indent=2))
    plan_summary = {k: plan.get(k) for k in
                    ("diets", "diets_reason", "effort_pair", "calorie_pair")}
    slots = {
        "DISH_JSON": json.dumps(dish, ensure_ascii=False, indent=2),
        "PLAN_SUMMARY_JSON": json.dumps(plan_summary, ensure_ascii=False,
                                        indent=2),
        "CELL_JSON": json.dumps(cell_doc, ensure_ascii=False, indent=2),
        "LEGACY_BLOCK": legacy_block,
        "SIBLINGS_SUMMARY": sibling_summary(siblings),
        "INGREDIENT_CATALOG": ctx.catalog,
        "COMPOUND_EXPANSIONS": ctx.compound_text(),
        "TECHNIQUES": ", ".join(ctx.techniques),
        "CONTAINS_FLAGS": ctx.contains_flags_text(),
        "MODE_NOTES": mode_notes,
    }
    latest, older, prev = list(initial_feedback or []), [], None

    def bounce(items):
        nonlocal latest, older
        older = [n for n in older + latest if n not in items][-10:]
        latest = items

    for attempt in range(1, args.max_attempts + 1):
        log(dish_id, f"{rid}: writing (attempt {attempt})")
        reply = codex_call(args, fill(ctx.prompts["writer"],
                                      {**slots,
                                       "FEEDBACK": feedback_block(
                                           latest, older, prev)}),
                           dish_id, f"{rid}-write-{attempt}")
        recipe, parse_err = extract_json(reply)
        if recipe is None:
            bounce([f"your reply was not parseable JSON ({parse_err}) — "
                    "output exactly one JSON object, nothing else"])
            continue
        prev = recipe
        errors, warnings = mech_recipe_check(ctx, dish_id, plan_path, cell,
                                             recipe, siblings, must_avoid)
        if errors:
            log(dish_id, f"{rid}: {len(errors)} mechanical error(s)")
            bounce(errors)
            continue
        verdict = review_call(
            args, ctx, dish_id, "recipe-reviewer",
            {"DISH_JSON": slots["DISH_JSON"],
             "CELL_JSON": slots["CELL_JSON"],
             "SIBLINGS_SUMMARY": slots["SIBLINGS_SUMMARY"],
             "VALIDATOR_WARNINGS": "\n".join(warnings) or "none",
             "MODE_NOTES": mode_notes,
             "RECIPE_JSON": json.dumps(recipe, ensure_ascii=False, indent=2)},
            f"{rid}-review-{attempt}")
        if verdict.get("approved") is True:
            write_json(path, recipe)
            log(dish_id, f"{rid}: accepted (attempt {attempt})")
            return recipe
        items = (verdict.get("must_fix") or [])[:8]
        if verdict.get("feedback"):
            items.append(verdict["feedback"])
        if not items:
            items = ["the reviewer rejected without specifics — tighten "
                     "kitchen physics, nutrition honesty, cell-truth and "
                     "both language voices, then resubmit"]
        bounce(items)
        log(dish_id, f"{rid}: reviewer bounced")
    raise PipelineError(f"{dish_id}: cell {rid} not accepted after "
                        f"{args.max_attempts} attempts")


def route_dish_errors(plan, recipes, errors):
    """Map dish-level validator errors to cells to bounce: id -> feedback."""
    bounce = {}
    cell_ids = [c["recipe_id"]
                for c in plan.get("cells", []) + plan.get("extras", [])]
    coverage = plan.get("coverage", {})
    for err in errors:
        matched = False
        for rid in cell_ids:
            if err.startswith(f"{rid}:"):
                bounce.setdefault(rid, []).append(err)
                matched = True
        if matched:
            continue
        m = re.search(r"no recipe visible for (\w+)-avoiding profile", err)
        if m and coverage.get(m.group(1)) in cell_ids:
            bounce.setdefault(coverage[m.group(1)], []).append(
                f"{err} — this cell carries that coverage duty; rebuild it "
                "without the blocking flags")
            continue
        m = re.search(r"duplicate (titles|captions)\[(\w+)\]", err)
        if m:
            # Recompute duplicates directly — the validator message quotes
            # values in repr form, which is not worth parsing.
            field = "title" if m.group(1) == "titles" else "caption"
            lang = m.group(2)
            seen = set()
            for r in recipes:
                value = r[field][lang].strip().lower()
                if value in seen:
                    bounce.setdefault(r["id"], []).append(
                        f"your {field}[{lang}] \"{value}\" duplicates an "
                        "earlier cell — write a distinct one")
                seen.add(value)
            continue
        # Unroutable error — caller turns this into a hard failure.
        bounce.setdefault("__dish__", []).append(err)
    return bounce


def assemble_dish(args, ctx, dish, plan):
    dish_id = dish["id"]
    done_path = WORK / "dishes" / f"{dish_id}.json"
    if done_path.exists():
        return
    plan_path = WORK / "plans" / f"{dish_id}.json"
    cells = ordered_cells(plan)

    def write_cells():
        recipes, siblings = [], []
        for cell in cells:
            recipe = cell_stage(args, ctx, dish, plan, cell, siblings)
            siblings.append(recipe)
            recipes.append(recipe)
        return recipes

    def redo(rid, notes):
        """Rewrite one cell against the freshest accepted siblings on disk."""
        (WORK / "recipes" / dish_id / f"{rid}.json").unlink(missing_ok=True)
        cell = next(c for c in cells if c["recipe_id"] == rid)
        others = []
        for c in cells:
            path = WORK / "recipes" / dish_id / f"{c['recipe_id']}.json"
            if c["recipe_id"] != rid and path.exists():
                others.append(read_json(path))
        cell_stage(args, ctx, dish, plan, cell, others,
                   initial_feedback=notes)

    def validate_and_bounce(recipes, rounds):
        for round_no in range(rounds):
            errors, _ = validate_tmp({"dish_id": dish_id,
                                      "recipes": recipes},
                                     "--dish", "--plan-file", plan_path)
            if not errors:
                return recipes
            bounce = route_dish_errors(plan, recipes, errors)
            if "__dish__" in bounce or round_no == rounds - 1:
                raise PipelineError(f"{dish_id}: dish-level validation "
                                    f"failed: {errors[:6]}")
            for rid, notes in bounce.items():
                log(dish_id, f"dish check bounced {rid}")
                redo(rid, notes)
            recipes = write_cells()
        return recipes

    recipes = validate_and_bounce(write_cells(), 3)

    for round_no in range(1, 3):
        verdict = review_call(
            args, ctx, dish_id, "dish-reviewer",
            {"DISH_JSON": json.dumps(dish, ensure_ascii=False, indent=2),
             "PLAN_JSON": json.dumps(plan, ensure_ascii=False, indent=2),
             "RECIPES_JSON": json.dumps(recipes, ensure_ascii=False,
                                        indent=2)},
            f"dish-review-{round_no}")
        bounce = verdict.get("bounce") or []
        if verdict.get("approved") is True and not bounce:
            write_json(done_path, {"dish_id": dish_id, "recipes": recipes})
            log(dish_id, f"dish accepted ({len(recipes)} recipes)")
            return
        valid = [b for b in bounce if isinstance(b, dict)
                 and any(c["recipe_id"] == b.get("recipe_id")
                         for c in cells)]
        for item in bounce:
            if item not in valid:
                log(dish_id, f"dish review named unknown cell {item!r} — "
                             "dropped")
        if not valid:
            raise PipelineError(f"{dish_id}: dish reviewer rejected without "
                                f"a usable bounce list: "
                                f"{verdict.get('feedback')}")
        for item in valid:
            log(dish_id, f"dish review bounced {item['recipe_id']}")
            redo(item["recipe_id"],
                 [item.get("feedback") or "dish reviewer bounced this cell"])
        recipes = validate_and_bounce(write_cells(), 2)
    raise PipelineError(f"{dish_id}: dish reviewer still bouncing after 2 "
                        "rounds — inspect pipeline/wave4/recipes/" + dish_id)


def run_dish(args, ctx, dish):
    try:
        plan = plan_stage(args, ctx, dish)
        assemble_dish(args, ctx, dish, plan)
        return None
    except BudgetExceeded:
        raise
    except PipelineError as exc:
        log(dish["id"], f"FAILED: {exc}")
        return str(exc)


# ------------------------------------------------------------------- scout

def loc_ok(v):
    return (isinstance(v, dict) and isinstance(v.get("en"), str)
            and isinstance(v.get("de"), str) and v["en"].strip()
            and v["de"].strip())


@as_feedback
def mech_scout_errors(ctx, doc, requested_name):
    if not isinstance(doc, dict) or not isinstance(doc.get("dish"), dict):
        return ["reply must be a JSON object with a 'dish' object"]
    errors = []
    dish = doc["dish"]
    did = dish.get("id")
    if not isinstance(did, str) or not re.fullmatch(r"[a-z0-9-]+", did):
        errors.append(f"bad dish id {did!r}")
    elif did in ctx.dish_by_id:
        errors.append(f"dish id '{did}' already exists")
    for field in ("name", "hero", "caption"):
        if not loc_ok(dish.get(field)):
            errors.append(f"dish.{field} missing en/de")
    if dish.get("recipes") != []:
        errors.append('dish.recipes must be the empty list []')
    part_ids = {p["id"] for p in ctx.manifest["partitions"]}
    if dish.get("partition_id") not in part_ids:
        errors.append(f"partition_id '{dish.get('partition_id')}' is not "
                      f"one of {sorted(part_ids)}")
    secondary = dish.get("secondary_partitions", [])
    if not isinstance(secondary, list) or not set(
            x for x in secondary if isinstance(x, str)) <= part_ids \
            or any(not isinstance(x, str) for x in secondary):
        errors.append(f"bad secondary_partitions {secondary}")
    if not isinstance(dish.get("stripe"), str) or not re.fullmatch(
            r"#[0-9a-fA-F]{6}", dish.get("stripe") or ""):
        errors.append(f"stripe '{dish.get('stripe')}' is not #rrggbb")
    if dish.get("frequency_tier") not in FREQUENCY_TIERS:
        errors.append(f"frequency_tier '{dish.get('frequency_tier')}' not "
                      f"in {sorted(FREQUENCY_TIERS)}")
    tags = dish.get("cuisine_tags")
    if not isinstance(tags, list) or not 1 <= len(tags) <= 4 \
            or any(not isinstance(t, str) for t in tags):
        errors.append(f"cuisine_tags must be 1-4 strings, got {tags}")
    known_flags = {f["id"] for f in ctx.ontology["contains_flags"]}
    new_ings = doc.get("new_ingredients") or []
    if not isinstance(new_ings, list) or len(new_ings) > 6:
        errors.append("new_ingredients must be a list of at most 6")
        new_ings = []
    seen_new = set()
    for ing in new_ings:
        if not isinstance(ing, dict):
            errors.append(f"new ingredient {ing!r} is not an object")
            continue
        iid = ing.get("id")
        if not isinstance(iid, str) or not re.fullmatch(r"[a-z0-9-]+", iid):
            errors.append(f"bad new ingredient id {iid!r}")
        elif iid in ctx.ing_flags:
            errors.append(f"ingredient '{iid}' already exists in the "
                          "catalog — use it, don't redefine it")
        elif iid in seen_new:
            errors.append(f"new ingredient '{iid}' proposed twice")
        else:
            seen_new.add(iid)
        if ing.get("parent") not in ctx.ing_flags:
            errors.append(f"new ingredient {iid}: parent "
                          f"'{ing.get('parent')}' is not an existing "
                          "catalog node")
        if not loc_ok(ing.get("name")):
            errors.append(f"new ingredient {iid}: name missing en/de")
        flags = ing.get("flags")
        if not isinstance(flags, list) or set(
                x for x in flags if isinstance(x, str)) - known_flags \
                or any(not isinstance(x, str) for x in flags):
            errors.append(f"new ingredient {iid}: flags must be a list "
                          f"from the contains-flags vocabulary, got {flags}")
    # Whether the proposal really is the requested dish (canonical spelling
    # may legitimately differ from the request) is the reviewer's judgment.
    return errors


def scout_slots(ctx, requested_name):
    request = (f'The dish to add: "{requested_name}". Research its canonical '
               "form (correct spelling and diacritics in both languages) "
               "and fill in everything else."
               if requested_name else
               "Invent exactly ONE new dish this corpus is missing. Look at "
               "the existing list: balance cuisines, meal types (breakfast/"
               "dessert/weeknight dinners), and pick something people "
               "genuinely cook and crave — not a novelty.")
    return {
        "REQUEST": request,
        "EXISTING_DISHES": ctx.existing_dishes_text(),
        "PARTITIONS": ctx.partitions_text(),
        "INGREDIENT_CATALOG": ctx.catalog,
        "CONTAINS_FLAGS": ctx.contains_flags_text(),
    }


def scout_stage(args, ctx, requested_name):
    """Research one new dish's baseline (entry + missing ingredients)."""
    label = requested_name or "(suggest)"
    slots = scout_slots(ctx, requested_name)
    latest, older, prev = [], [], None
    for attempt in range(1, args.max_attempts + 1):
        log("scout", f"{label}: researching (attempt {attempt})")
        reply = codex_call(args, fill(ctx.prompts["dish-scout"],
                                      {**slots,
                                       "FEEDBACK": feedback_block(
                                           latest, older, prev)}),
                           "scout", f"scout-{attempt}")
        doc, parse_err = extract_json(reply)
        if doc is None:
            older = [n for n in older + latest][-10:]
            latest = [f"your reply was not parseable JSON ({parse_err})"]
            continue
        prev = doc
        errors = mech_scout_errors(ctx, doc, requested_name)
        if errors:
            older = [n for n in older + latest if n not in errors][-10:]
            latest = errors
            continue
        verdict = review_call(args, ctx, "scout", "scout-reviewer",
                              {**slots,
                               "PROPOSAL_JSON": json.dumps(
                                   doc, ensure_ascii=False, indent=2)},
                              f"scout-review-{attempt}")
        if verdict.get("approved") is True:
            log("scout", f"{label}: accepted as "
                         f"'{doc['dish']['id']}' (attempt {attempt})")
            return doc
        older = [n for n in older + latest][-10:]
        latest = [verdict.get("feedback") or "reviewer rejected the dish"]
    raise PipelineError(f"scout: {label} not accepted after "
                        f"{args.max_attempts} attempts")


def insert_ingredient(ing_doc, parent_id, node):
    """Insert a new leaf under parent_id. Returns True when inserted."""
    def walk(n):
        if n.get("id") == parent_id:
            n.setdefault("children", []).append(node)
            return True
        return any(walk(ch) for ch in n.get("children", []))
    return any(walk(root) for root in ing_doc["nodes"])


def apply_scout(ctx, doc):
    """Persist an accepted scout result: catalog additions + pending dish."""
    new_ings = doc.get("new_ingredients") or []
    if new_ings:
        ing_doc = read_json(ASSETS / "ingredients.json")
        for ing in new_ings:
            node = {"id": ing["id"], "name": ing["name"],
                    "flags": ing.get("flags") or []}
            if not insert_ingredient(ing_doc, ing["parent"], node):
                raise PipelineError(f"scout: parent node '{ing['parent']}' "
                                    "vanished from ingredients.json")
            log("scout", f"ingredient added: {ing['id']} "
                         f"(under {ing['parent']}, "
                         f"flags {ing.get('flags') or 'none'})")
        write_json(ASSETS / "ingredients.json", ing_doc)
    pending_path = WORK / "pending-dishes.json"
    pending = read_json(pending_path) if pending_path.exists() else []
    pending.append(doc["dish"])
    write_json(pending_path, pending)
    log("scout", f"dish '{doc['dish']['id']}' queued (pending until its "
                 "lattice ships)")


# ---------------------------------------------------------------- coverage

_impossible_lock = threading.Lock()


def load_impossible():
    path = WORK / "coverage-impossible.json"
    return read_json(path) if path.exists() else {}


def record_impossible(key, reason):
    with _impossible_lock:
        registry = load_impossible()
        registry[key] = reason
        write_json(WORK / "coverage-impossible.json", registry)


def combo_iter(max_size):
    """Avoid-group combinations: all singles, then pairs, then triples …"""
    from itertools import combinations
    for size in range(1, max_size + 1):
        yield from combinations(COVERAGE_GROUPS, size)


def combo_key(combo):
    return "-".join(k for k, _ in combo)


def combo_flat(combo):
    flat = set()
    for _, flags in combo:
        flat |= flags
    return flat


def triple_of(r):
    v = r.get("variant", {})
    return (v.get("diet"), v.get("effort"), v.get("calorie"))


def coverage_work_for(ctx, dish_ids, combo):
    """dish_id -> [(base_cell, coverage_recipe_id)] still uncovered."""
    flat = combo_flat(combo)
    suffix = "no-" + combo_key(combo)
    impossible = load_impossible()
    work = {}
    for dish_id in dish_ids:
        dish_path = WORK / "dishes" / f"{dish_id}.json"
        plan_path = WORK / "plans" / f"{dish_id}.json"
        if not dish_path.exists() or not plan_path.exists():
            continue  # lattice not done yet — the base run handles it
        plan = read_json(plan_path)
        recipes = read_json(dish_path)["recipes"]
        items = []
        for cell in ordered_cells(plan):
            triple = (cell["diet"], cell["effort"], cell["calorie"])
            at_triple = [r for r in recipes if triple_of(r) == triple]
            if any(not (set(r.get("contains", [])) & flat)
                   for r in at_triple):
                continue  # some recipe at these coords already fits
            key = f"{cell['recipe_id']}-{suffix}"
            if key in impossible:
                continue
            items.append((cell, key))
        if items:
            work[dish_id] = items
    return work


def process_coverage_dish(args, ctx, dish, combo, items):
    dish_id = dish["id"]
    flat = combo_flat(combo)
    names = ", ".join(k for k, _ in combo)
    plan_path = WORK / "plans" / f"{dish_id}.json"
    dish_path = WORK / "dishes" / f"{dish_id}.json"
    produced = 0
    for cell, key in items:
        plan = read_json(plan_path)
        cov_list = plan.setdefault("coverage_cells", [])
        if not any(c.get("recipe_id") == key for c in cov_list):
            cov_list.append({"recipe_id": key, "diet": cell["diet"],
                             "effort": cell["effort"],
                             "calorie": cell["calorie"],
                             "free_of": sorted(flat)})
            write_json(plan_path, plan)
        doc = read_json(dish_path)
        base = next((r for r in doc["recipes"]
                     if r["id"] == cell["recipe_id"]), None)
        mode_notes = (
            "## Coverage variant\n\n"
            f"This recipe is the {cell['diet']}/{cell['effort']}/"
            f"{cell['calorie']} cell of this dish, fully re-authored for "
            f"people who avoid: {names}. Closeness in spirit to the base "
            "cell below is INTENDED — same dish, same coordinates, its own "
            "proud recipe without those ingredients. Do not copy the base "
            "cell's prose; title, caption and intro must be its own.\n\n"
            "Base cell recipe:\n"
            + json.dumps(base, ensure_ascii=False, indent=2))
        cov_cell = {
            "recipe_id": key, "diet": cell["diet"],
            "effort": cell["effort"], "calorie": cell["calorie"],
            "intent": (f"the {cell['diet']}/{cell['effort']}/"
                       f"{cell['calorie']} cell, written without {names} — "
                       "same dish, complete and proud"),
            "must_avoid": sorted(flat | ctx.column_avoid(cell["diet"])),
        }
        def unregister():
            doc_plan = read_json(plan_path)
            doc_plan["coverage_cells"] = [
                c for c in doc_plan.get("coverage_cells", [])
                if c.get("recipe_id") != key]
            write_json(plan_path, doc_plan)

        try:
            recipe = cell_stage(args, ctx, dish, plan, cov_cell,
                                siblings=doc["recipes"],
                                mode_notes=mode_notes)
        except CodexUnavailable:
            # Infrastructure trouble says nothing about the recipe —
            # unregister and let a rerun retry it.
            unregister()
            raise
        except PipelineError as exc:
            log(dish_id, f"coverage {key}: impossible ({exc})")
            record_impossible(key, str(exc)[:300])
            unregister()
            continue
        doc = read_json(dish_path)
        if not any(r["id"] == key for r in doc["recipes"]):
            doc["recipes"].append(recipe)
            write_json(dish_path, doc)
        errors, _ = validate_tmp(doc, "--dish", "--plan-file", plan_path)
        if errors:
            log(dish_id, f"coverage {key}: post-accept validation failed "
                         f"{errors[:3]} — rolled back")
            doc["recipes"] = [r for r in doc["recipes"] if r["id"] != key]
            write_json(dish_path, doc)
            (WORK / "recipes" / dish_id / f"{key}.json").unlink(
                missing_ok=True)
            record_impossible(key, f"dish validation: {errors[:3]}")
            unregister()
            continue
        produced += 1
    return produced


def expand_coverage(args, ctx, dish_ids, single_combo=False, max_size=None):
    """Walk the avoid-combination space; returns recipes produced."""
    produced = 0
    for combo in combo_iter(max_size or args.max_combo_size):
        work = coverage_work_for(ctx, dish_ids, combo)
        if not work:
            continue
        total = sum(len(v) for v in work.values())
        log("coverage", f"no-{combo_key(combo)}: {total} uncovered cell(s) "
                        f"across {len(work)} dish(es)")
        with ThreadPoolExecutor(max_workers=args.jobs) as pool:
            counts = list(pool.map(
                lambda kv: process_coverage_dish(
                    args, ctx, ctx.dish_by_id[kv[0]], combo, kv[1]),
                work.items()))
        produced += sum(counts)
        if not args.no_merge:
            merge_corpus(ctx)
        if single_combo:
            break
    return produced


# ------------------------------------------------------------------- merge

def merge_corpus(ctx):
    missing = [d["id"] for d in ctx.dishes
               if not (WORK / "dishes" / f"{d['id']}.json").exists()]
    if missing:
        print(f"merge blocked — {len(missing)} dish(es) not done yet: "
              f"{', '.join(missing[:8])}{'…' if len(missing) > 8 else ''}")
        return False

    orphaned = ({d["partition_id"] for d in ctx.dishes}
                - {p["id"] for p in ctx.manifest["partitions"]})
    if orphaned:
        print(f"merge blocked — dish partition_id(s) {sorted(orphaned)} "
              "missing from partition-manifest.json")
        return False

    errors, warnings = run_validator("--dishes", WORK / "dishes",
                                     "--plans", WORK / "plans",
                                     "--current", WORK / "current")
    if errors:
        print("merge blocked — corpus-wide validation failed:")
        for err in errors[:20]:
            print(f"  ERROR {err}")
        return False
    for warning in warnings[:15]:
        print(f"  warning {warning}")

    by_dish = {d["id"]: read_json(WORK / "dishes" / f"{d['id']}.json")
               ["recipes"] for d in ctx.dishes}
    for part in ctx.manifest["partitions"]:
        recipes = []
        for dish in ctx.dishes:
            if dish["partition_id"] == part["id"]:
                recipes.extend(by_dish[dish["id"]])
        write_json(REPO / "app" / part["file"],
                   {"partition_id": part["id"], "recipes": recipes})

    dishes_doc = read_json(ASSETS / "dishes.json")
    shipped_ids = {d["id"] for d in dishes_doc["dishes"]}
    for entry in ctx.pending:
        if entry["id"] not in shipped_ids:
            dishes_doc["dishes"].append(entry)
    for dish in dishes_doc["dishes"]:
        dish["recipes"] = [r["id"] for r in by_dish[dish["id"]]]
    write_json(ASSETS / "dishes.json", dishes_doc)
    if ctx.pending:
        print(f"shipped {len(ctx.pending)} new dish(es): "
              f"{', '.join(d['id'] for d in ctx.pending)}")
        write_json(WORK / "pending-dishes.json", [])
        ctx.pending = []

    manifest = read_json(ASSETS / "partition-manifest.json")
    today = date.today()
    prefix = f"{today.year}.{today.month:02d}"
    seq = 1
    old = manifest.get("corpus_version", "")
    if old.startswith(prefix):
        try:
            seq = int(old.rsplit(".", 1)[1]) + 1
        except ValueError:
            pass
    manifest["corpus_version"] = f"{prefix}.{seq}"
    manifest["corpus_wave"] = 4
    for part in manifest["partitions"]:
        part["dish_ids"] = [d["id"] for d in ctx.dishes
                            if d["partition_id"] == part["id"]]
    write_json(ASSETS / "partition-manifest.json", manifest)

    total = sum(len(r) for r in by_dish.values())
    print(f"\nmerged {total} recipes across {len(ctx.dishes)} dishes into "
          f"app/assets (corpus {manifest['corpus_version']}, wave 4)")
    print("next: pipeline/tests/run_tests.sh && (cd app && flutter test)")
    return True


# ------------------------------------------------------------------ status

def show_status(ctx, dish_ids):
    done = planned = cells = coverage = 0
    pending_ids = {d["id"] for d in ctx.pending}
    for dish_id in dish_ids:
        plan_path = WORK / "plans" / f"{dish_id}.json"
        dish_done = (WORK / "dishes" / f"{dish_id}.json").exists()
        if plan_path.exists():
            planned += 1
            plan = read_json(plan_path)
            total = len(plan.get("cells", [])) + len(plan.get("extras", []))
            cov = len(plan.get("coverage_cells", []))
            coverage += cov
            have = len(list((WORK / "recipes" / dish_id).glob("*.json"))
                       if (WORK / "recipes" / dish_id).exists() else [])
            cells += have
            state = "DONE" if dish_done else f"{have}/{total} cells"
            if cov:
                state += f" (+{cov} coverage)"
        else:
            state = "no plan"
        if dish_id in pending_ids:
            state += "  [pending ship]"
        if dish_done:
            done += 1
        print(f"  {dish_id:<18} {state}")
    impossible = len(load_impossible())
    print(f"\n{done}/{len(dish_ids)} dishes done, {planned} planned, "
          f"{cells} recipes accepted ({coverage} coverage variants"
          f"{f', {impossible} recorded impossible' if impossible else ''})")


# --------------------------------------------------------------- self-test

def self_test():
    failures = []

    def check(name, cond):
        print(("ok   " if cond else "FAIL ") + name)
        if not cond:
            failures.append(name)

    check("extract_json plain", extract_json('{"a": 1}') == ({"a": 1}, None))
    check("extract_json fenced",
          extract_json('text\n```json\n{"a": {"b": "}"}}\n```') ==
          ({"a": {"b": "}"}}, None))
    check("extract_json prefixed",
          extract_json('the plan:\n{"a": [1, 2], "s": "x{y}"} trailing') ==
          ({"a": [1, 2], "s": "x{y}"}, None))
    check("extract_json garbage", extract_json("no json here")[0] is None)
    # A bad escape mid-reply must surface the parse error, not a salvaged
    # inner fragment (the fragment would generate nonsense feedback).
    broken = ('{"id": "real-recipe", "intro": "a "quote" broke this", '
              '"macros": {"calories": 300}, "tags": {"en": ["x"]}}')
    parsed, perr = extract_json(broken)
    check("extract_json rejects fragments of broken JSON",
          parsed is None and perr is not None)

    ctx = Ctx()
    check("catalog has seitan", "seitan" in ctx.ing_flags)
    check("catalog inherits flags", "dairy" in ctx.ing_flags.get(
        "parmesan", set()))
    check("profile avoid sets complete",
          set(ctx.profile_avoid) == set(COVERAGE_PROFILES))

    plan = {"diets": ["classic", "vegan"], "effort_pair": ["easy", "medium"],
            "calorie_pair": ["le400", "le600"],
            "cells": [{"recipe_id": f"d-{d}-{e}-{CAL_SHORT[c]}", "diet": d,
                       "effort": e, "calorie": c}
                      for d in ("classic", "vegan")
                      for e in ("easy", "medium")
                      for c in ("le400", "le600")],
            "extras": [{"recipe_id": "d-gluten-free-easy-400",
                        "diet": "gluten-free", "effort": "easy",
                        "calorie": "le400"}],
            "coverage": {"gluten": "d-gluten-free-easy-400"}}
    cells = ordered_cells(plan)
    check("ordered_cells puts classic first, extras last",
          cells[0]["diet"] == "classic" and cells[-1]["diet"] == "gluten-free")
    check("effective_must_avoid applies coverage",
          effective_must_avoid(ctx, plan)["d-gluten-free-easy-400"]
          == {"gluten"})

    recipes = [{"id": "d-classic-easy-400",
                "title": {"en": "t", "de": "T"},
                "caption": {"en": "c", "de": "C"}}]
    routed = route_dish_errors(plan, recipes,
                               ["d-classic-easy-400: 3 steps (need 4-8)",
                                "d: no recipe visible for gluten-avoiding "
                                "profile"])
    check("route_dish_errors maps recipe + coverage errors",
          set(routed) == {"d-classic-easy-400", "d-gluten-free-easy-400"})

    lint = text_lint({"title": {"en": "Big Bowl", "de": "kleine schüssel"},
                      "caption": {"en": "simply delicious", "de": "ok"},
                      "intro": {"en": "tofu instead of egg", "de": "ok"},
                      "steps": []})
    check("text_lint catches bans + casing", len(lint) >= 4)

    combos = list(combo_iter(2))
    singles = len(COVERAGE_GROUPS)
    check("combo_iter walks singles before pairs",
          len(combos[0]) == 1 and combos[0][0][0] == "gluten"
          and all(len(c) == 1 for c in combos[:singles])
          and all(len(c) == 2 for c in combos[singles:]))
    pair = (COVERAGE_GROUPS[0], COVERAGE_GROUPS[2])  # gluten + nuts
    check("combo key + flat", combo_key(pair) == "gluten-nuts"
          and combo_flat(pair) == {"gluten"} | NUT_FLAGS)
    check("column_avoid vegan covers dairy and egg",
          {"dairy", "egg"} <= ctx.column_avoid("vegan")
          and ctx.column_avoid("classic") == set())
    if (WORK / "dishes" / "tomato-soup.json").exists():
        fish_work = coverage_work_for(ctx, ["tomato-soup"],
                                      (("fish", frozenset({"fish"})),))
        check("coverage_work_for skips fully-covered combos",
              fish_work == {})

    good_scout = {
        "dish": {"id": "test-okonomiyaki",
                 "name": {"en": "okonomiyaki", "de": "Okonomiyaki"},
                 "hero": {"en": "x", "de": "x"},
                 "caption": {"en": "x", "de": "x"}, "stripe": "#A1B2C3",
                 "recipes": [], "partition_id": "cuisine-asian",
                 "secondary_partitions": [], "cuisine_tags": ["japanese"],
                 "frequency_tier": "medium"},
        "new_ingredients": [{"id": "test-bonito-flakes",
                             "parent": "fish-seafood",
                             "name": {"en": "x", "de": "x"},
                             "flags": ["fish"], "why": "x"}]}
    check("mech_scout_errors accepts a sound proposal",
          mech_scout_errors(ctx, good_scout, "okonomiyaki") == [])
    bad = json.loads(json.dumps(good_scout))
    bad["dish"]["id"] = "doener"
    bad["new_ingredients"][0]["parent"] = "no-such-node"
    bad["new_ingredients"][0]["flags"] = ["wheat"]
    errs = mech_scout_errors(ctx, bad, None)
    check("mech_scout_errors flags dup id, bad parent, bad flags",
          len(errs) >= 3)

    ing_copy = json.loads((ASSETS / "ingredients.json").read_text())
    inserted = insert_ingredient(ing_copy, "garlic",
                                 {"id": "test-leaf", "name": {}, "flags": []})

    def find_node(nodes, node_id):
        for n in nodes:
            if n.get("id") == node_id:
                return n
            hit = find_node(n.get("children", []), node_id)
            if hit:
                return hit
        return None

    garlic = find_node(ing_copy["nodes"], "garlic")
    check("insert_ingredient lands under its parent",
          inserted and garlic is not None and any(
              ch.get("id") == "test-leaf"
              for ch in garlic.get("children", [])))

    for name, template in ctx.prompts.items():
        slots = set(re.findall(r"\{\{([A-Z_]+)\}\}", template))
        try:
            fill(template, {s: "x" for s in slots})
            check(f"prompt {name} fills cleanly", True)
        except RuntimeError:
            check(f"prompt {name} fills cleanly", False)

    print()
    if failures:
        print(f"{len(failures)} self-test failure(s)")
        return 1
    print("wave4_lattice self-test passed")
    return 0


# -------------------------------------------------------------------- main

def main():
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dishes", default="all",
                    help="comma-separated dish ids (default: all)")
    ap.add_argument("--jobs", type=int, default=4,
                    help="dishes processed in parallel (default 4)")
    ap.add_argument("--max-attempts", type=int, default=6,
                    help="write→review attempts per artifact (default 6)")
    ap.add_argument("--model", default=None,
                    help="codex model for writers (default: codex config)")
    ap.add_argument("--review-model", default=None,
                    help="codex model for reviewers (default: --model)")
    ap.add_argument("--codex-cmd", default="codex")
    ap.add_argument("--call-timeout", type=int, default=900,
                    help="seconds per codex call (default 900)")
    ap.add_argument("--call-budget", type=int, default=0,
                    help="abort after N codex calls (0 = unlimited)")
    ap.add_argument("--no-merge", action="store_true",
                    help="never touch app/assets, even when all dishes pass")
    ap.add_argument("--merge-only", action="store_true")
    ap.add_argument("--status", action="store_true")
    ap.add_argument("--reset-dish", metavar="ID",
                    help="forget plan+cells+dish for one dish, then exit")
    ap.add_argument("--new-dish", metavar="NAME",
                    help="research one named dish (spelling, names, tags, "
                         "missing ingredients), then generate its full "
                         "lattice and merge")
    ap.add_argument("--suggest-dish", type=int, nargs="?", const=1,
                    default=0, metavar="N",
                    help="let codex invent N new dishes (baseline entries "
                         "only — queued; the next run writes their recipes)")
    ap.add_argument("--expand-coverage", action="store_true",
                    help="author allergen-coverage variants: for every "
                         "lattice cell, versions free of avoid-combinations "
                         "(singles, then pairs, …) up to --max-combo-size")
    ap.add_argument("--max-combo-size", type=int, default=2,
                    help="largest avoid-combination for --expand-coverage "
                         "(default 2)")
    ap.add_argument("--forever", action="store_true",
                    help="run indefinitely: finish lattices, merge, expand "
                         "coverage one combination per cycle, scout one new "
                         "dish, repeat — until interrupted or the call "
                         "budget runs out")
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()

    if args.self_test:
        sys.exit(self_test())

    ctx = Ctx()
    if args.dishes == "all":
        dish_ids = [d["id"] for d in ctx.dishes]
    else:
        dish_ids = [d.strip() for d in args.dishes.split(",") if d.strip()]
        unknown = [d for d in dish_ids if d not in ctx.dish_by_id]
        if unknown:
            sys.exit(f"unknown dish ids: {unknown}")

    if args.reset_dish:
        for path in [WORK / "plans" / f"{args.reset_dish}.json",
                     WORK / "dishes" / f"{args.reset_dish}.json"]:
            path.unlink(missing_ok=True)
        rdir = WORK / "recipes" / args.reset_dish
        if rdir.exists():
            for f in rdir.glob("*.json"):
                f.unlink()
        if any(d["id"] == args.reset_dish for d in ctx.pending):
            write_json(WORK / "pending-dishes.json",
                       [d for d in ctx.pending
                        if d["id"] != args.reset_dish])
            print(f"reset {args.reset_dish} (also unqueued — it was a "
                  "pending dish)")
        else:
            print(f"reset {args.reset_dish}")
        return

    snapshot_current(ctx)

    if args.status:
        show_status(ctx, dish_ids)
        return
    if args.merge_only:
        sys.exit(0 if merge_corpus(ctx) else 1)

    def run_batch(ctx, ids):
        todo = [ctx.dish_by_id[d] for d in ids
                if not (WORK / "dishes" / f"{d}.json").exists()]
        if not todo:
            return {}
        print(f"{len(ids) - len(todo)} dish(es) already done, "
              f"{len(todo)} to go, {args.jobs} in parallel\n")
        failures = {}
        with ThreadPoolExecutor(max_workers=args.jobs) as pool:
            for dish, err in zip(todo, pool.map(
                    lambda d: run_dish(args, ctx, d), todo)):
                if err:
                    failures[dish["id"]] = err
        return failures

    try:
        if args.new_dish:
            doc = scout_stage(args, ctx, args.new_dish)
            apply_scout(ctx, doc)
            ctx = Ctx()  # pick up the new dish + catalog additions
            snapshot_current(ctx)
            new_id = doc["dish"]["id"]
            err = run_dish(args, ctx, ctx.dish_by_id[new_id])
            if err:
                print(f"\n{new_id}: lattice failed ({err}) — rerun "
                      f"`--dishes {new_id}` to resume; the dish stays "
                      "queued and unshipped")
                sys.exit(1)
            if not args.no_merge:
                sys.exit(0 if merge_corpus(ctx) else 1)
            return

        if args.suggest_dish:
            for _ in range(args.suggest_dish):
                ctx = Ctx()  # each suggestion sees the grown list
                apply_scout(ctx, scout_stage(args, ctx, None))
            print(f"\n{args.suggest_dish} dish(es) queued — a normal run "
                  "writes their lattices and ships them at merge")
            return

        if args.expand_coverage:
            produced = expand_coverage(args, ctx, dish_ids)
            print(f"\ncoverage pass complete — {produced} new recipe(s) up "
                  f"to combo size {args.max_combo_size}; raise "
                  "--max-combo-size (or use --forever) for more")
            return

        if args.forever:
            cycle = 0
            while True:
                cycle += 1
                print(f"\n━━ forever cycle {cycle} ━━")
                ctx = Ctx()
                snapshot_current(ctx)
                failures = run_batch(ctx, [d["id"] for d in ctx.dishes])
                if failures:
                    print(f"{len(failures)} dish(es) failed this cycle "
                          "(will retry next cycle): "
                          f"{', '.join(failures)}")
                elif not args.no_merge:
                    merge_corpus(ctx)
                produced = expand_coverage(
                    args, ctx, [d["id"] for d in ctx.dishes],
                    single_combo=True, max_size=len(COVERAGE_GROUPS))
                scouted = 0
                if failures:
                    # Don't grow the queue while dishes are stuck — that
                    # blocks every merge and burns calls without shipping.
                    print("skipping the dish scout while dishes are "
                          "failing; fix or --reset-dish them")
                else:
                    try:
                        apply_scout(ctx, scout_stage(args, ctx, None))
                        scouted = 1
                    except CodexUnavailable:
                        raise
                    except PipelineError as exc:
                        print(f"scout failed this cycle ({exc}) — "
                              "continuing")
                print(f"cycle {cycle}: {produced} coverage recipe(s), "
                      f"{scouted} dish(es) scouted")

        failures = run_batch(ctx, dish_ids)
    except BudgetExceeded as exc:
        print(f"\nstopped: {exc} (rerun to resume)")
        sys.exit(1)
    except CodexUnavailable as exc:
        print(f"\nstopped: codex unavailable ({exc}) — nothing was marked "
              "impossible; rerun to resume")
        sys.exit(1)
    except PipelineError as exc:
        print(f"\nstopped: {exc} (state is on disk; rerun to resume)")
        sys.exit(1)

    print()
    show_status(ctx, dish_ids)
    if failures:
        print(f"\n{len(failures)} dish(es) failed — rerun to retry, or "
              "--reset-dish to replan:")
        for dish_id, err in failures.items():
            print(f"  {dish_id}: {err}")
        sys.exit(1)

    if args.dishes == "all" and not args.no_merge:
        sys.exit(0 if merge_corpus(ctx) else 1)
    elif args.dishes != "all":
        print("\nsubset run complete — full merge happens when all dishes "
              "are done (run without --dishes)")


if __name__ == "__main__":
    main()
