"""Authoring DSL for the MorphCook corpus.

A dish holds one fully-written base recipe plus a patch per sibling variant.
The builder materialises every variant into a complete, standalone recipe —
nothing in the shipped JSON refers back to a "base". That is the load-bearing
idea of the product: each variant is its own recipe, not a diff.
"""

from dataclasses import dataclass, field
from typing import Optional


def L(en: str, de: str) -> dict:
    return {"en": en, "de": de}


@dataclass
class Ing:
    id: str
    qty: Optional[float]
    unit: str
    note_en: str = ''
    note_de: str = ''
    optional: bool = False

    def to_json(self) -> dict:
        out = {"ingredient_id": self.id, "qty": self.qty, "unit": self.unit}
        if self.note_en or self.note_de:
            out["note"] = L(self.note_en, self.note_de)
        if self.optional:
            out["optional"] = True
        return out


def ing(i, qty, unit, note_en='', note_de='', optional=False) -> Ing:
    return Ing(i, qty, unit, note_en, note_de, optional)


@dataclass
class Step:
    en: str
    de: str
    timer: Optional[int] = None  # seconds

    def to_json(self) -> dict:
        out = {"text": L(self.en, self.de)}
        if self.timer:
            out["timer_seconds"] = self.timer
        return out


def step(en, de, timer=None) -> Step:
    return Step(en, de, timer)


@dataclass
class Patch:
    """How one variant differs from the dish's base recipe."""
    drop: list = field(default_factory=list)
    swap: dict = field(default_factory=dict)      # old_id -> Ing
    add: list = field(default_factory=list)       # [Ing]
    qty: dict = field(default_factory=dict)       # id -> new qty
    steps: dict = field(default_factory=dict)     # index -> Step
    steps_insert: list = field(default_factory=list)   # [(index, Step)]
    steps_append: list = field(default_factory=list)   # [Step]
    steps_drop: list = field(default_factory=list)     # [index]


@dataclass
class Variant:
    slug: str
    diet: str
    title_en: str
    title_de: str
    blurb_en: str
    blurb_de: str
    hand_en: str
    hand_de: str
    effort: str
    minutes: int
    kcal: int
    macros: tuple           # (protein_g, carbs_g, fat_g)
    patch: Patch = field(default_factory=Patch)
    servings: Optional[int] = None
    extra_contains: list = field(default_factory=list)
    attrs: list = field(default_factory=list)
    tech: list = field(default_factory=list)
    tips: list = field(default_factory=list)   # [(en, de)]
    is_base: bool = False


def variant(slug, diet, title, blurb, hand, effort, minutes, kcal, macros,
            patch=None, servings=None, extra_contains=None, attrs=None,
            tech=None, tips=None, is_base=False) -> Variant:
    return Variant(
        slug=slug, diet=diet,
        title_en=title[0], title_de=title[1],
        blurb_en=blurb[0], blurb_de=blurb[1],
        hand_en=hand[0], hand_de=hand[1],
        effort=effort, minutes=minutes, kcal=kcal, macros=macros,
        patch=patch or Patch(), servings=servings,
        extra_contains=extra_contains or [], attrs=attrs or [],
        tech=tech or [], tips=tips or [], is_base=is_base,
    )


@dataclass
class Dish:
    id: str
    name_en: str
    name_de: str
    hero_en: str
    hero_de: str
    cap_en: str
    cap_de: str
    stripe: str
    cuisines: list
    categories: list
    partition: str
    secondary: list
    tier: int
    slots: list
    servings: int
    base_ing: list
    base_steps: list
    variants: list
    tags: list = field(default_factory=list)


def dish(id, name, hero, cap, stripe, cuisines, categories, partition,
         secondary, tier, slots, servings, base_ing, base_steps, variants,
         tags=None) -> Dish:
    return Dish(
        id=id, name_en=name[0], name_de=name[1],
        hero_en=hero[0], hero_de=hero[1],
        cap_en=cap[0], cap_de=cap[1],
        stripe=stripe, cuisines=cuisines, categories=categories,
        partition=partition, secondary=secondary, tier=tier, slots=slots,
        servings=servings, base_ing=base_ing, base_steps=base_steps,
        variants=variants, tags=tags or [],
    )


def apply_patch(base_ing: list, base_steps: list, patch: Patch):
    """Materialise a variant's ingredient list and method from the base."""
    ings = []
    for item in base_ing:
        if item.id in patch.drop:
            continue
        if item.id in patch.swap:
            ings.append(patch.swap[item.id])
            continue
        if item.id in patch.qty:
            ings.append(Ing(item.id, patch.qty[item.id], item.unit,
                            item.note_en, item.note_de, item.optional))
            continue
        ings.append(item)
    ings.extend(patch.add)

    steps = []
    for i, s in enumerate(base_steps):
        if i in patch.steps_drop:
            continue
        steps.append(patch.steps.get(i, s))
    for (index, s) in sorted(patch.steps_insert, key=lambda x: -x[0]):
        steps.insert(index, s)
    steps.extend(patch.steps_append)
    return ings, steps
