"""Голоси ElevenLabs (українські) для кожного персонажа. Ті самі, що в «Маленькому кур'єрі»."""

VOICES = {
    "marichka": "NzxZZhrUg9MwxGQtQRFf",   # Marichka Kvitka - Bright and Playful
    "yulya":    "eahEXQKDeSog4IvDWkWl",   # Pani Yulya - Warm & Playful
    "daryna":   "VRgXeW5yzeo9Vlv0JZ1A",   # Daryna Holub - bright, high
    "olga":     "lkMXdLVaZ3W8mreYvUGj",   # Olga - Soft & Calm
    "anna":     "GTK070oXAiMGygBZc96P",   # Anna Rudenko - cute
    "leonid":   "hIe25X4hL68hNwSL41Ll",   # Leonid Polishchuk - cheerful
    "nestor":   "GVAs5c0aXpTTBsFQ9emv",   # Nestor Lipich - young
    "adrian":   "vUZbo4a4aVWCFt2ZCOXF",   # Adrian H. - 22 years
    "mykola":   "jsQZaQ22xaNCrus7aTPu",   # Mykola - Christmas Storyteller
    "rolik":    "0B3pAkYGlTLkwZDmsGmC",   # Rolik - Warm & Natural
    "opovidach": "K74pMNmxBnAW8cPpeyph",  # Opovidach - Calm & Deep
}

# персонаж -> голос
SPEAKERS = {
    "narrator": "marichka",
    "chief": "mykola",        # Капітан Бобер
    "dog": "leonid",          # пожежник Бровко
    "bunny": "daryna",        # поліцейська Зоя
    "fox": "yulya",           # пілотка Ліса
    "bear": "rolik",          # моряк Михась
    "cat": "anna", "duck": "anna", "hedgehog": "nestor", "owl": "opovidach",
    "raccoon": "adrian", "mouse": "daryna", "frog": "anna", "pig": "rolik",
    "squirrel": "yulya", "turtle": "olga", "deer": "olga", "goat": "nestor",
}

MODEL = "eleven_multilingual_v2"
SETTINGS = {"stability": 0.5, "similarity_boost": 0.8, "style": 0.35, "use_speaker_boost": True}
