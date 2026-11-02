"""Compact authoring helpers for the recipe corpus.

Recipes are authored as plain data so they stay readable in review. The
builder turns them into the shipped JSON, deriving the contains-flags from
the ingredients so the corpus is always self-consistent.
"""

from __future__ import annotations

from dataclasses import dataclass, field


@dataclass
class Ingredient:
    id: str
    name_en: str
    name_de: str
    quantity: float
    unit: str
    prep_en: str = ""
    prep_de: str = ""
    note_en: str = ""
    note_de: str = ""
    optional: bool = False


@dataclass
class Step:
    en: str
    de: str
    timer: int | None = None


@dataclass
class Recipe:
    id: str
    dish: str
    diet: str
    title_en: str
    title_de: str
    hero_en: str
    hero_de: str
    caption_en: str
    caption_de: str
    color: str
    effort: str
    minutes: int
    calories: int
    protein: float
    carbs: float
    fat: float
    servings: int
    meal_slots: list[str]
    tags_en: list[str]
    tags_de: list[str]
    ingredients: list[Ingredient]
    steps: list[Step]
    extra_flags: list[str] = field(default_factory=list)
    extra_certifications: list[str] = field(default_factory=list)
    techniques: list[str] = field(default_factory=list)


@dataclass
class Dish:
    id: str
    name_en: str
    name_de: str
    hero_en: str
    hero_de: str
    caption_en: str
    caption_de: str
    color: str
    cuisines: list[str]
    tier: str  # "core" or "extended"
    tags_en: list[str]
    tags_de: list[str]


def I(
    id: str,
    name_en: str,
    name_de: str,
    quantity: float,
    unit: str,
    prep: tuple[str, str] = ("", ""),
    note: tuple[str, str] = ("", ""),
    optional: bool = False,
) -> Ingredient:
    return Ingredient(
        id=id,
        name_en=name_en,
        name_de=name_de,
        quantity=quantity,
        unit=unit,
        prep_en=prep[0],
        prep_de=prep[1],
        note_en=note[0],
        note_de=note[1],
        optional=optional,
    )


def S(en: str, de: str, timer: int | None = None) -> Step:
    return Step(en=en, de=de, timer=timer)


def R(
    *,
    id: str,
    dish: str,
    diet: str,
    title: tuple[str, str],
    hero: tuple[str, str],
    caption: tuple[str, str],
    color: str,
    effort: str,
    minutes: int,
    calories: int,
    macros: tuple[float, float, float],
    servings: int,
    meal_slots: list[str],
    tags: tuple[list[str], list[str]],
    ingredients: list[Ingredient],
    steps: list[Step],
    extra_flags: list[str] | None = None,
    extra_certifications: list[str] | None = None,
    techniques: list[str] | None = None,
) -> Recipe:
    return Recipe(
        id=id,
        dish=dish,
        diet=diet,
        title_en=title[0],
        title_de=title[1],
        hero_en=hero[0],
        hero_de=hero[1],
        caption_en=caption[0],
        caption_de=caption[1],
        color=color,
        effort=effort,
        minutes=minutes,
        calories=calories,
        protein=macros[0],
        carbs=macros[1],
        fat=macros[2],
        servings=servings,
        meal_slots=meal_slots,
        tags_en=tags[0],
        tags_de=tags[1],
        ingredients=ingredients,
        steps=steps,
        extra_flags=extra_flags or [],
        extra_certifications=extra_certifications or [],
        techniques=techniques or [],
    )


def D(
    *,
    id: str,
    name: tuple[str, str],
    hero: tuple[str, str],
    caption: tuple[str, str],
    color: str,
    cuisines: list[str],
    tier: str,
    tags: tuple[list[str], list[str]],
) -> Dish:
    return Dish(
        id=id,
        name_en=name[0],
        name_de=name[1],
        hero_en=hero[0],
        hero_de=hero[1],
        caption_en=caption[0],
        caption_de=caption[1],
        color=color,
        cuisines=cuisines,
        tier=tier,
        tags_en=tags[0],
        tags_de=tags[1],
    )
