# JENKINS-INSTANTLY

## Сборка с дефолтными настройками
## Сборка и запуск
Клонируем репозиторий.
```shell script
git clone https://github.com/DmitryTravyan/jenkins-instantly.git
```

Переходим в корневую директорию клонированного проекта и запускаем make для  
просмотра возможных команд
```shell script
make help
```

Собираем образы jenkins и vault:
```shell script
make dc-build
```

Для пересборки docker образов (если была допущена ошибка) используйте:
```shell script
make dc-build-no-cache
```

Перед запуском на локальной машине (проверялось на MacOS и Linux), добавьте  
записи для обращения к jenkins и vault по именам jenkins.local и  
vault.local
```shell script
sudo -- sh -c 'cat <<EOF >> /etc/hosts
# Added for jenkins-instantly
0.0.0.0 jenkins.local
0.0.0.0 vault.local
# End of section'
```

Разрешите докеру монтирование директорий.
```shell
./vault/shared
./jenkins/shared
```

Теперь мы можем запустить jenkins и vault локально.
```shell script
make dc-start
```

Проверяем что все контейнеры запущены.
```shell
docker ps | grep '-local'
```

В браузере проверяем доступность [https://jenkins.local](https://jenkins.local)  
Логин `admin`, пароль `admin`.

Теперь нужно инициализировать vault, полный процесс и документацию смотрите  
[HTTP APIs](https://learn.hashicorp.com/tutorials/vault/getting-started-apis?in=vault/getting-started).  
У нас будет упрощенный вариант, с заранее подготовленным скриптом, поэтому  
вводим следующую команду:
```shell
make dc-vault-init
```

### Доступ и конфигурирование

Все конфиги сосредоточены в директории casc_configs

## Сборка с собственными параметрами

Клонируем репозиторий.
```shell script
git clone https://github.com/DmitryTravyan/jenkins-instantly.git
```

Открываем .env файл и редактируем параметры
```shell script
vim .env
```

