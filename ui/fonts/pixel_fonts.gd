class_name PixelFonts
extends RefCounted
## Пиксельные шрифты игры. Собираются tools/build_fonts.gd из ui/fonts/src/*.txt.
##
## Шрифты битмапные: рисовать только размером *_SIZE или его целым кратным
## (×2, ×3 — масштабируются без размытия). Другие размеры округляются вниз до целого кратного.

## Основной шрифт (RU + EN, строчные и заглавные). Высота строки 12 px, заглавная 7 px.
const BODY_SIZE := 12
## Заголовочный шрифт: только заглавные, «камень» с обводкой. Высота строки 18 px.
const TITLE_SIZE := 18

const BODY: FontFile = preload("res://ui/fonts/kraken_body.res")
const TITLE: FontFile = preload("res://ui/fonts/kraken_title.res")
const TITLE_GLOW: FontFile = preload("res://ui/fonts/kraken_title_glow.res")

## Вариации темы (theme_type_variation у Label).
const VARIATION_TITLE := &"TitleLabel"
const VARIATION_TITLE_GLOW := &"GlowTitleLabel"
