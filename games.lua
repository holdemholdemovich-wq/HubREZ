-- games.lua — список игр для HubREZ. Лежит в репозитории рядом со скриптами.
-- Чтобы добавить игру: загрузи файл скрипта в репозиторий и допиши сюда новый блок { ... }.
return {
	{
		name = "The Button",
		sub = "TheButtonREZ  ·  ESP",
		file = "TheButtonREZ_menu.lua",
		guiName = "TheButtonREZ",
		about = "TheButtonREZ — меню для игры The Button.\n\nЧто умеет:\n• ESP: боксы, трейсеры, ники, здоровье, дистанция, скелет\n• Стрелки-указатели на игроков за экраном\n• Настройка цветов, толщины линий и дальности\n• Работает на телефоне и ПК, сворачивается в кружок\n\nМеню открывается после нажатия Execute.",
	},
	{
		name = "Build A Boat For Treasure",
		sub = "BabftREZ  ·  Auto Farm",
		file = "BabftREZ.lua",
		guiName = "BabftREZ",
		placeId = 537413528,
		about = "BabftREZ — меню для Build A Boat For Treasure.\n\nЧто умеет:\n• Auto Farm: проходит этапы и забирает золото и сундук\n• Настройка стартового этапа, этапа сундука и задержки\n• Скорость, прыжок, Noclip, Fly (джойстик + камера на телефоне)\n• ESP игроков с никами и выбором цвета\n• Anti-AFK и Reset Character\n\nЗапускай внутри игры, на старте забега.",
	},
}
