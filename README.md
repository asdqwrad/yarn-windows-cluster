# YARN Cluster Deployment

Автоматизированное развертывание YARN на Windows 11 с использованием Docker Desktop и PowerShell.

Кластер включает:

- ResourceManager;
- NodeManager;
- WebAppProxy.

Docker Compose не используется.

## Требования

- Windows 11;
- Docker Desktop;
- PowerShell.

Docker Desktop должен быть запущен перед выполнением скрипта.

Проверить Docker:

```powershell
docker version
```

## Структура проекта

```text
.
├── README.md
├── config
│   └── yarn-site.xml
└── scripts
    ├── deploy.ps1
    └── stop.ps1
```

## Запуск

Открыть PowerShell в корневой директории проекта.

Если выполнение PowerShell-скриптов запрещено:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
```

Запустить автоматическое развертывание:

```powershell
.\scripts\deploy.ps1
```

Скрипт:

1. проверяет доступность Docker;
2. скачивает образ Apache Hadoop при необходимости;
3. создает Docker network;
4. запускает ResourceManager;
5. запускает NodeManager;
6. запускает WebAppProxy;
7. публикует веб-интерфейсы сервисов на хост-машине.

## Веб-интерфейсы

После запуска доступны:

| Сервис | Адрес |
| --- | --- |
| ResourceManager | http://localhost:8088 |
| NodeManager | http://localhost:8042 |
| WebAppProxy | http://localhost:9099 |

ResourceManager и NodeManager имеют собственные Web UI.

WebAppProxy опубликован на порту `9099` и используется для проксирования веб-интерфейсов YARN applications. У него нет обычной стартовой страницы, поэтому запрос к `/` или `/index.html` может возвращать HTTP 404 — это не означает, что сервис не запущен.

## Проверка

Проверить работающие контейнеры:

```powershell
docker ps
```

Должны быть запущены:

```text
resourcemanager
nodemanager
webappproxy
```

После этого открыть опубликованные веб-интерфейсы:

```text
http://localhost:8088
http://localhost:8042
http://localhost:9099
```

В интерфейсе ResourceManager должен отображаться зарегистрированный NodeManager.

Публикацию WebAppProxy можно проверить в выводе `docker ps`: порт `9099` должен быть проброшен на контейнер `webappproxy`.

## Логи

При необходимости:

```powershell
docker logs resourcemanager
docker logs nodemanager
docker logs webappproxy
```

## Остановка

```powershell
.\scripts\stop.ps1
```
