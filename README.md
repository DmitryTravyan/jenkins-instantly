# get jenkins as code from the one repo 

## Сборка своими силами
### Подготовка
```shell script
git clone https://github.com/DmitryTravyan/jenkins-instantly.git
```

Переходим в корневую директорию клонированного проекта и запускаем make для просмотра возможных команд
```shell script
make help
```

Открываем .env файл и редактируем параметры
```shell script
vim .env
```

### Сборка и запуск
Собираем образы jenkins и vault:
```shell script
make dc-build
```

Для пересборки docker образов (если была допущена ошибка) используйте:
```shell script
make dc-build-no-cache
```


Запускаем контейнер
```shell script
make dc-start
```

### Доступ и конфигурирование

Все конфиги сосредоточены в директории casc_configs

## next step
