# Тексты кампании (М23, DESIGN.md §8г) → i18n/campaign.csv.
# Запуск: python tools/build_campaign_text.py i18n/campaign.csv  (правьте тексты здесь, CSV — результат)
# Хоб говорит вежливо-зловеще, загадками, зовёт игрока «гость» (§5, §8д).
import csv, sys

T = []  # (key, ru, en)


def add(key, ru, en):
    T.append((key, ru, en))


# --- Меню и экран кампании ---
add("MENU_CAMPAIGN", "Кампания", "Campaign")
add("MENU_CAMPAIGN_FINISHED", "Кампания пройдена", "Campaign complete")
add("CAMP_TITLE", "КАМПАНИЯ", "CAMPAIGN")
add("CAMP_SUBTITLE", "Таверна «Шёпот Бездны»", "The Whisper of the Abyss tavern")
add("CAMP_LEVEL", "Уровень %d", "Level %d")
add("CAMP_PLAY", "Играть", "Play")
add("CAMP_COMPLETED", "Пройдено", "Completed")
add("CAMP_LOCKED", "Сначала пройдите «%s»", "Beat \"%s\" first")
add("CAMP_OPPONENTS", "Соперники:", "Opponents:")
add("CAMP_NO_MODIFIER", "Без особых правил", "No special rules")
add("CAMP_SECRET_OPPONENT", "Кто-то ждёт за стойкой…", "Someone waits behind the bar…")
add("CAMP_SECRET_MODIFIER", "???", "???")
add("CAMP_RULES_FIXED", "Palifico и Calza всегда включены", "Palifico and Calza are always on")
add("CAMP_PORTRAIT", "Портрет", "Portrait")
add("CAMP_INTRO", "Вступление", "Intro")
add("CAMP_RESTART", "Заново", "Restart")
add("CAMP_RESTART_TITLE", "Начать кампанию заново? Весь прогресс пропадёт.",
    "Restart the campaign? All progress will be lost.")
add("CAMP_RESTART_YES", "Начать заново", "Restart")
add("CAMP_RESTART_NO", "Отмена", "Cancel")
add("CAMP_PICK_PORTRAIT", "КТО ВЫ?", "WHO ARE YOU?")
add("CAMP_PICK_HINT", "Выберите портрет. Сменить его можно между уровнями.",
    "Choose a portrait. You can change it between levels.")
add("CAMP_PICK_OK", "Готово", "Done")
add("CAMP_SKIP", "Пропустить", "Skip")
add("CAMP_NEXT", "Дальше", "Next")
add("CAMP_HOB", "Старый Хоб", "Old Hob")
add("CAMP_END_TITLE", "КОНЕЦ", "THE END")
add("CAMP_END_TEXT", "Вы покинули остров. Но остров помнит своих должников…",
    "You have left the island. But the island remembers its debtors…")
add("CAMP_END_MENU", "В главное меню", "Main menu")
add("CAMP_TO_MAP", "К карте", "To the map")
add("CAMP_CONTINUE", "Дальше", "Continue")
add("CAMP_RETRY", "Ещё раз", "Try again")

# --- Модификаторы ---
add("CAMP_MOD_EVIL_EYE", "Дурной глаз", "Evil Eye")
add("CAMP_MOD_EVIL_EYE_DESC",
    "В начале каждого раунда Ведьма видит %d ваш кубик — он помечен глазом.",
    "At the start of each round the Witch sees %d of your dice — it is marked with an eye.")
add("CAMP_MOD_SCARCE_SANITY", "Скудный рассудок", "Scarce Sanity")
add("CAMP_MOD_SCARCE_SANITY_DESC", "У всех за столом %d Рассудка вместо %d.",
    "Everyone at the table has %d Sanity instead of %d.")
add("CAMP_MOD_DEAD_HAND", "Мёртвая рука", "Dead Hand")
add("CAMP_MOD_DEAD_HAND_DESC",
    "Утопленник, потеряв последний кубик, один раз за матч возвращается со дна с %d кубиком.",
    "Once per match, when the Drowned loses his last die, he returns from the deep with %d die.")
add("CAMP_MOD_LAIR", "Логово", "The Lair")
add("CAMP_MOD_LAIR_DESC",
    "У Глубоководного %d кубиков. Когда у него останется %d, придёт прилив: каждый раунд одна грань — джокер вместе с единицами (кроме Palifico).",
    "The Deep One has %d dice. When he is down to %d, the tide comes: each round one face is a joker along with ones (except in Palifico).")

# --- Стол ---
add("TABLE_TIDE", "ПРИЛИВ: %d", "TIDE: %d")
add("TABLE_MSG_TIDE", "Прилив! В этом раунде %d — джокер вместе с единицами.",
    "The tide! This round %d is a joker along with ones.")
add("TABLE_MSG_EVIL_EYE", "Дурной глаз: %s видит ваш кубик №%d.",
    "Evil Eye: %s sees your die #%d.")
add("TABLE_NOTE_RESCUED", "%s тонет… и возвращается со дна с %d кубиком!",
    "%s drowns… and returns from the deep with %d die!")
add("TABLE_MSG_WHISPER_TIDE", "(прилив %d — тоже джокер)", "(tide %d is a joker too)")

# --- Уровни: название и место на карте ---
LEVELS = [
    ("Мокрые карманы", "Wet Pockets", "Скамья у двери", "Bench by the door"),
    ("Отмель", "The Shallows", "Длинный стол", "The long table"),
    ("Ведьмин угол", "Witch's Corner", "Угол у окна", "Corner by the window"),
    ("Круг посвящённых", "Circle of the Initiated", "Задняя комната", "The back room"),
    ("Те, кто не ушёл", "Those Who Stayed", "Подвал", "The cellar"),
    ("Хозяин таверны", "Master of the Tavern", "Стойка", "The bar"),
]
for i, (ru, en, pru, pen) in enumerate(LEVELS, 1):
    add(f"CAMP_L{i}_NAME", ru, en)
    add(f"CAMP_L{i}_PLACE", pru, pen)

# --- Сцены с Хобом: перед уровнем и после победы ---
SCENES = {
    1: (
        [("Первый стол, гость. Моряк — такой же, как ты: море выплюнуло его на этот берег.",
          "Your first table, guest. The Sailor is like you: the sea spat him onto this shore."),
         ("Только он застрял давно. Очень давно.",
          "Only he got stuck long ago. Very long ago."),
         ("Здесь жульничают все. Не говори потом, что старый Хоб не предупреждал.",
          "Everyone cheats here. Don't say old Hob didn't warn you.")],
        [("Неплохо для утопленника, гость. Ох, прости — для выжившего.",
          "Not bad for a drowned man, guest. Oh, forgive me — for a survivor."),
         ("Вода на стойке? Это с кружки капает. Она у меня вечно мокрая.",
          "Water on the bar? It drips from the mug. It's always wet, this one.")],
    ),
    2: (
        [("С берега приползли гости: Улитс, Ихтиандр и Крабер.",
          "Guests have crawled in from the shore: Ulits, Ichthyander and Craber."),
         ("Они пахнут отливом и не любят чужаков. Стол на четверых — держи ухо востро.",
          "They smell of low tide and don't like strangers. A table of four — keep your wits.")],
        [("Берег тебя признал, гость. Это редкость.",
          "The shore has accepted you, guest. That's rare."),
         ("Что ты смотришь на мои руки? Пальцев ровно столько, сколько нужно.",
          "Why stare at my hands? There are exactly as many fingers as needed.")],
    ),
    3: (
        [("Ведьмин угол. Ведьма и малыш Омен.",
          "The Witch's corner. The Witch and little Omen."),
         ("У Ведьмы дурной глаз: в каждом раунде она видит один твой кубик. Какой — увидишь и ты.",
          "The Witch has the evil eye: each round she sees one of your dice. You'll see which one."),
         ("А Омен любит предсказывать. Не слушай его. Или слушай.",
          "And Omen loves to prophesy. Don't listen to him. Or do.")],
        [("Омен сказал, что ты не уйдёшь с острова? Дети болтают.",
          "Omen said you won't leave the island? Children chatter."),
         ("Хотя этот ребёнок ещё ни разу не ошибся.",
          "Though that child has never been wrong yet.")],
    ),
    4: (
        [("Круг посвящённых: Оккультист, Чумной культист и Учёный.",
          "The Circle of the Initiated: the Occultist, the Plague Cultist and the Scholar."),
         ("Учёный был корабельным врачом. Тоже хотел уплыть. Теперь он считает свечи.",
          "The Scholar was a ship's doctor. He wanted to leave too. Now he counts candles."),
         ("Рядом с Кругом рассудок тает быстрее. У всех за столом его будет меньше.",
          "Near the Circle sanity melts faster. Everyone at the table will have less of it.")],
        [("Культ молится тому, кто живёт под островом. Не смейся, гость.",
          "The cult prays to the one who lives beneath the island. Don't laugh, guest."),
         ("Он слышит. Он всегда слышит.", "He hears. He always hears.")],
    ),
    5: (
        [("Подвал. Здесь сидят те, кто не ушёл.",
          "The cellar. Here sit those who never left."),
         ("Утопленник был капитаном. Проиграл Мастеру Ужаса — и остался. Мёртвая рука держит крепко: один раз он вернётся со дна.",
          "The Drowned was a captain. He lost to the Horror Master — and stayed. The dead hand holds tight: once, he will return from the deep."),
         ("Мастер Ужаса вежлив. Не верь вежливым, гость.",
          "The Horror Master is polite. Never trust the polite, guest.")],
        [("Ты обыграл Мастера. Никто не обыгрывал Мастера.",
          "You beat the Master. No one has ever beaten the Master."),
         ("Остался последний стол, гость. Мой.",
          "One table left, guest. Mine.")],
    ),
    6: (
        [("Все столы пройдены. Лодка у причала, гость. Почти.",
          "Every table is beaten. The boat is at the pier, guest. Almost."),
         ("Ты ведь хотел знать, почему у меня мокрые руки? И сколько на них пальцев?",
          "You wanted to know why my hands are wet? And how many fingers they have?"),
         ("Хозяин таверны — я. Садись. В моём логове у меня шесть костей, и прилив на моей стороне.",
          "I am the master of this tavern. Sit. In my lair I hold six dice, and the tide is on my side.")],
        [("…Иди, гость. Лодка твоя.", "…Go, guest. The boat is yours."),
         ("Но остров не отпускает должников. Он просто ждёт.",
          "But the island never lets its debtors go. It simply waits.")],
    ),
}
for n, (before, after) in SCENES.items():
    for i, (ru, en) in enumerate(before, 1):
        add(f"CAMP_L{n}_BEFORE_{i}", ru, en)
    for i, (ru, en) in enumerate(after, 1):
        add(f"CAMP_L{n}_AFTER_{i}", ru, en)

# --- Слайды ---
INTRO = [
    ("Шторм третьи сутки. Корабль трещит, как старая бочка.",
     "The storm has raged for three days. The ship creaks like an old barrel."),
    ("Вспышка молнии — и скалы прямо по курсу. Удар. Тьма.",
     "A flash of lightning — and rocks dead ahead. A crash. Darkness."),
    ("Вы приходите в себя на мокром песке. Вдали, сквозь дождь, горит одинокий огонёк.",
     "You wake on wet sand. Far off, through the rain, a lone light is burning."),
    ("Огонёк — фонарь над дверью таверны. На вывеске: «Шёпот Бездны».",
     "The light is a lantern above a tavern door. The sign reads: \"The Whisper of the Abyss\"."),
    ("За стойкой — грузный бармен с бородой в водорослях. «Остров не отпускает должников, гость. Обыграй всех, кто сидит в этом зале, — и я дам тебе лодку».",
     "Behind the bar stands a heavy barkeep, seaweed in his beard. \"The island never lets its debtors go, guest. Beat everyone in this hall — and I'll give you a boat.\""),
]
FINALE = [
    ("Глубоководный роняет кости. Его глаза гаснут, как фонари в тумане.",
     "The Deep One drops his dice. His eyes go dark like lanterns in the fog."),
    ("Таверна стонет. Сквозь доски хлещет вода, стены осыпаются в море.",
     "The tavern groans. Water bursts through the boards, the walls crumble into the sea."),
    ("Рассвет. У причала качается лодка — как и было обещано.",
     "Dawn. A boat rocks at the pier — just as promised."),
    ("Вы гребёте прочь от острова. А под вами, на дне, медленно открывается огромный глаз.",
     "You row away from the island. And beneath you, on the seabed, a vast eye slowly opens."),
]
for i, (ru, en) in enumerate(INTRO, 1):
    add(f"CAMP_INTRO_{i}", ru, en)
for i, (ru, en) in enumerate(FINALE, 1):
    add(f"CAMP_FINALE_{i}", ru, en)

# --- Достижения кампании (§8а) ---
add("ACH_LEAVE_ISLAND", "Покинуть остров", "Leave the Island")
add("ACH_LEAVE_ISLAND_DESC", "Пройдите кампанию", "Complete the campaign")
add("ACH_CLEAN_CONSCIENCE", "Чистая совесть", "Clear Conscience")
add("ACH_CLEAN_CONSCIENCE_DESC", "Пройдите уровень кампании без трюков",
    "Beat a campaign level without tricks")
add("ACH_NO_RETREAT", "Ни шагу назад", "Not One Step Back")
add("ACH_NO_RETREAT_DESC", "Пройдите кампанию без поражений",
    "Finish the campaign with no defeats")

out = sys.argv[1] if len(sys.argv) > 1 else "i18n/campaign.csv"
with open(out, "w", encoding="utf-8", newline="") as f:
    w = csv.writer(f, lineterminator="\n")
    w.writerow(["keys", "en", "ru"])
    for key, ru, en in T:
        w.writerow([key, en, ru])
print(len(T), "strings")
