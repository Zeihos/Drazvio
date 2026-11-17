# DRAZVIO

**DRAZVIO** — сервер SA-MP 0.3.7-R2 с режимами Drift и DeathMatch. Основной мод написан на Pawn. Проект активно дорабатывается; релизная стабильность пока не подтверждена.

## Структура репозитория

| Каталог | Содержимое |
| --- | --- |
| server/gamemodes | Исходник основного мода |
| server/filterscripts | 11 игровых фильтрскриптов и девять необходимых готовых AMX |
| server/pawno | Pawn 3.2.3664 и заголовки |
| server/plugins | sscanf и streamer |
| server/scriptfiles | Только статические игровые материалы |
| native/filefunctions_compat | Исходники и тесты нового FileFunctions для Windows x86 |
| tools | Сборка, диагностика, подготовка тестового ZIP |
| assets/branding | Логотип, обложки, материалы публикаций |

## Сборка (Windows)

Требуются PowerShell и Python 3. Для сборки Pawn используйте:

```powershell
python tools/drazvio.py check
./tools/build.ps1
```

Результаты — в build-amx. Сборка не перезаписывает рабочий сервер без явного параметра -Install. Перед установкой сделайте резервную копию.

Локальный приватный конфиг и отсутствующие начальные файлы scriptfiles/data создаются командой (существующие сохранения не перезаписываются):

```powershell
python tools/drazvio.py init
```

В GitHub Actions запускаются Pawn build и FileFunctions compatibility (experimental). После успешного запуска полного сервера доступен артефакт **DRAZVIO-SERVER-TEST** с чистой тестовой сборкой. Это не финальный релиз.

## Требования и безопасность

- Устаревший FileFunctions.dll зависел от отладочной MSVCR100D.dll. В CI собирается тестируемая Release-замена.
- Legacy streamer.dll требует Microsoft Visual C++ 2010 Redistributable x86.
- Реальные server.cfg, аккаунты, балансы, IP игроков и резервные копии нельзя добавлять в Git.
- Старые ZIP и данные, однажды попавшие в Git, остаются доступны в истории. Смените прежний RCON-пароль и другие опубликованные секреты.
- При обновлении действующего сервера сохраните server.cfg и всю папку scriptfiles. Не заменяйте данные игроков тестовым архивом.

До v1.0 остаются игровые тесты регистрации, экономики, недвижимости и нагрузки.
