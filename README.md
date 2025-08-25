
#  Дипломная работа по профессии «Системный администратор»

## Инфраструктура
Для развёртки инфраструктуры используйте Terraform и Ansible.  
<img width="1920" height="1080" alt="terraform" src="https://github.com/user-attachments/assets/2989de13-ac48-4ade-9a1f-96de49a96678" />
<img width="1568" height="472" alt="yandex-cloud-vms" src="https://github.com/user-attachments/assets/372ce728-da5c-4593-a932-0cee2917ff58" />

Не используйте для ansible inventory ip-адреса! Вместо этого используйте fqdn имена виртуальных машин в зоне ".ru-central1.internal". Пример: example.ru-central1.internal  - для этого достаточно при создании ВМ указать name=example, hostname=examle !! 
На всех хостах использовал fqdn имена, кроме бастиона:
<img width="1458" height="280" alt="inv" src="https://github.com/user-attachments/assets/8bf9235b-d669-4963-a26e-1d0fe144da1e" />

### Сайт
Создайте две ВМ в разных зонах, установите на них сервер nginx, если его там нет. ОС и содержимое ВМ должно быть идентичным, это будут наши веб-сервера.

Используйте набор статичных файлов для сайта. Можно переиспользовать сайт из домашнего задания.
<img width="378" height="360" alt="nginx-ansible" src="https://github.com/user-attachments/assets/57d6e2ad-e895-401f-9905-a977adc6c451" />

<img width="773" height="363" alt="web-access" src="https://github.com/user-attachments/assets/f5e6fa08-5a85-4984-9de1-f3858520d3b5" />

Виртуальные машины не должны обладать внешним Ip-адресом, те находится во внутренней сети. Доступ к ВМ по ssh через бастион-сервер. Доступ к web-порту ВМ через балансировщик yandex cloud.
<img width="1326" height="422" alt="cloud network map" src="https://github.com/user-attachments/assets/1666b964-048b-4a56-8690-e4aa46d2490a" />

<img width="708" height="379" alt="curl-web-load balancer" src="https://github.com/user-attachments/assets/249879bd-9717-47ba-8e07-ccb5013e7104" />
<img width="1108" height="400" alt="подключение через bastion" src="https://github.com/user-attachments/assets/558cf249-c064-498b-9b06-3e92b7964ad5" />

Настройка балансировщика:

1. Создайте [Target Group](https://cloud.yandex.com/docs/application-load-balancer/concepts/target-group), включите в неё две созданных ВМ.
2. <img width="488" height="352" alt="target group" src="https://github.com/user-attachments/assets/df1a2570-484d-4088-ab89-0b64b42080c9" />

3. Создайте [Backend Group](https://cloud.yandex.com/docs/application-load-balancer/concepts/backend-group), настройте backends на target group, ранее созданную. Настройте healthcheck на корень (/) и порт 80, протокол HTTP. 

<img width="716" height="416" alt="web-backend group" src="https://github.com/user-attachments/assets/f45ccceb-1daa-4604-ba75-0d6b84422947" />

3. Создайте [HTTP router](https://cloud.yandex.com/docs/application-load-balancer/concepts/http-router). Путь укажите — /, backend group — созданную ранее.

<img width="722" height="473" alt="router" src="https://github.com/user-attachments/assets/365da542-f112-492f-9782-ab88413b0ac6" />


4. Создайте [Application load balancer](https://cloud.yandex.com/en/docs/application-load-balancer/) для распределения трафика на веб-сервера, созданные ранее. Укажите HTTP router, созданный ранее, задайте listener тип auto, порт 80.

Протестируйте сайт
`curl -v <публичный IP балансера>:80` 

<img width="708" height="379" alt="curl-web-load balancer" src="https://github.com/user-attachments/assets/bf8d55bb-f0e6-4b91-8fea-2a29a9938c19" />
<img width="706" height="733" alt="web-alb-listener" src="https://github.com/user-attachments/assets/b67944be-a03b-4855-b6a8-777e80a59747" />

### Мониторинг
Создайте ВМ, разверните на ней Zabbix. На каждую ВМ установите Zabbix Agent, настройте агенты на отправление метрик в Zabbix. 
<img width="675" height="1040" alt="zabbix-server-ansible" src="https://github.com/user-attachments/assets/65259022-9e98-4bd6-a897-9979116954e3" />
<img width="503" height="892" alt="zabbix-agent-ansible" src="https://github.com/user-attachments/assets/57dcbba9-8d1c-4bd2-a6f2-67901a947771" />


Настройте дешборды с отображением метрик, минимальный набор — по принципу USE (Utilization, Saturation, Errors) для CPU, RAM, диски, сеть, http запросов к веб-серверам. Добавьте необходимые tresholds на соответствующие графики.

<img width="1035" height="696" alt="zabbix-initial" src="https://github.com/user-attachments/assets/28a4c949-77f5-43ba-9dcd-3e09cb81d7ff" />
<img width="1458" height="218" alt="zabbix-hosts" src="https://github.com/user-attachments/assets/c0de60b5-04f0-47a8-8820-3aec7a8127ea" />
<img width="1692" height="870" alt="zabbix-all" src="https://github.com/user-attachments/assets/5f801fdf-40f2-45a1-81b8-b235537d6605" />
<img width="1688" height="966" alt="zabbix-web-servers" src="https://github.com/user-attachments/assets/8c2a0258-c1a0-466d-8689-d6aa838a151c" />
<img width="1620" height="753" alt="zabbix-web-servers2" src="https://github.com/user-attachments/assets/6fdb3a3c-ea68-43e0-a8fd-c7b0846f161e" />

### Логи
Cоздайте ВМ, разверните на ней Elasticsearch. Установите filebeat в ВМ к веб-серверам, настройте на отправку access.log, error.log nginx в Elasticsearch.

Создайте ВМ, разверните на ней Kibana, сконфигурируйте соединение с Elasticsearch.
<img width="620" height="906" alt="kibana-elastic-filebeat" src="https://github.com/user-attachments/assets/a4c3b6df-419a-4e2e-a67d-0e3be72e8768" />
<img width="1913" height="939" alt="filebeat" src="https://github.com/user-attachments/assets/8b2f672f-537b-46f3-81a9-189f88f8290b" />
<img width="1913" height="1028" alt="kibana-elastic" src="https://github.com/user-attachments/assets/80316655-9275-4e64-94dc-73ae535ae6c8" />


### Сеть
Разверните один VPC. Сервера web, Elasticsearch поместите в приватные подсети. Сервера Zabbix, Kibana, application load balancer определите в публичную подсеть.
<img width="1433" height="223" alt="subnets" src="https://github.com/user-attachments/assets/7d3fe2d0-4da1-40f5-b1c6-30a5d344db80" />

<img width="1585" height="308" alt="public ips" src="https://github.com/user-attachments/assets/4038189e-e2db-4b3c-8c28-895c45fbebef" />

Настройте [Security Groups](https://cloud.yandex.com/docs/vpc/concepts/security-groups) соответствующих сервисов на входящий трафик только к нужным портам.<img width="1225" height="412" alt="sg" src="https://github.com/user-attachments/assets/c3d0926b-8d04-4238-9ebf-a412a273278e" />


Настройте ВМ с публичным адресом, в которой будет открыт только один порт — ssh.  Эта вм будет реализовывать концепцию  [bastion host]( https://cloud.yandex.ru/docs/tutorials/routing/bastion) . Синоним "bastion host" - "Jump host". Подключение  ansible к серверам web и Elasticsearch через данный bastion host можно сделать с помощью  [ProxyCommand](https://docs.ansible.com/ansible/latest/network/user_guide/network_debug_troubleshooting.html#network-delegate-to-vs-proxycommand) . Допускается установка и запуск ansible непосредственно на bastion host.(Этот вариант легче в настройке)
Скриншот выше

Исходящий доступ в интернет для ВМ внутреннего контура через [NAT-шлюз](https://yandex.cloud/ru/docs/vpc/operations/create-nat-gateway).
<img width="762" height="415" alt="Доступ в интернет через nat шлюз" src="https://github.com/user-attachments/assets/5c7c1409-ae54-4a3f-bde2-f04ed46ec795" />



### Резервное копирование
Создайте snapshot дисков всех ВМ. Ограничьте время жизни snaphot в неделю. Сами snaphot настройте на ежедневное копирование.
<img width="1772" height="549" alt="snapshot" src="https://github.com/user-attachments/assets/4ad36b94-0bb3-468b-a084-3381fadb78e1" />
<img width="760" height="650" alt="schedule snapshot" src="https://github.com/user-attachments/assets/f6f161d8-1f48-446f-b75f-29b7e3cc9fc3" />

### Дополнительно
Не входит в минимальные требования. 

1. Для Zabbix можно реализовать разделение компонент - frontend, server, database. Frontend отдельной ВМ поместите в публичную подсеть, назначте публичный IP. Server поместите в приватную подсеть, настройте security group на разрешение трафика между frontend и server. Для Database используйте [Yandex Managed Service for PostgreSQL](https://cloud.yandex.com/en-ru/services/managed-postgresql). Разверните кластер из двух нод с автоматическим failover.
2. Вместо конкретных ВМ, которые входят в target group, можно создать [Instance Group](https://cloud.yandex.com/en/docs/compute/concepts/instance-groups/), для которой настройте следующие правила автоматического горизонтального масштабирования: минимальное количество ВМ на зону — 1, максимальный размер группы — 3.
3. В Elasticsearch добавьте мониторинг логов самого себя, Kibana, Zabbix, через filebeat. Можно использовать logstash тоже.
4. Воспользуйтесь Yandex Certificate Manager, выпустите сертификат для сайта, если есть доменное имя. Перенастройте работу балансера на HTTPS, при этом нацелен он будет на HTTP веб-серверов.

## Выполнение работы
На этом этапе вы непосредственно выполняете работу. При этом вы можете консультироваться с руководителем по поводу вопросов, требующих уточнения.

⚠️ В случае недоступности ресурсов Elastic для скачивания рекомендуется разворачивать сервисы с помощью docker контейнеров, основанных на официальных образах.

**Важно**: Ещё можно задавать вопросы по поводу того, как реализовать ту или иную функциональность. И руководитель определяет, правильно вы её реализовали или нет. Любые вопросы, которые не освещены в этом документе, стоит уточнять у руководителя. Если его требования и указания расходятся с указанными в этом документе, то приоритетны требования и указания руководителя.

## Критерии сдачи
1. Инфраструктура отвечает минимальным требованиям, описанным в [Задаче](#Задача).
2. Предоставлен доступ ко всем ресурсам, у которых предполагается веб-страница (сайт, Kibana, Zabbix).
3. Для ресурсов, к которым предоставить доступ проблематично, предоставлены скриншоты, команды, stdout, stderr, подтверждающие работу ресурса.
4. Работа оформлена в отдельном репозитории в GitHub или в [Google Docs](https://docs.google.com/), разрешён доступ по ссылке. 
5. Код размещён в репозитории в GitHub.
6. Работа оформлена так, чтобы были понятны ваши решения и компромиссы. 
7. Если использованы дополнительные репозитории, доступ к ним открыт. 

## Как правильно задавать вопросы дипломному руководителю
Что поможет решить большинство частых проблем:
1. Попробовать найти ответ сначала самостоятельно в интернете или в материалах курса и только после этого спрашивать у дипломного руководителя. Навык поиска ответов пригодится вам в профессиональной деятельности.
2. Если вопросов больше одного, присылайте их в виде нумерованного списка. Так дипломному руководителю будет проще отвечать на каждый из них.
3. При необходимости прикрепите к вопросу скриншоты и стрелочкой покажите, где не получается. Программу для этого можно скачать [здесь](https://app.prntscr.com/ru/).

Что может стать источником проблем:
1. Вопросы вида «Ничего не работает. Не запускается. Всё сломалось». Дипломный руководитель не сможет ответить на такой вопрос без дополнительных уточнений. Цените своё время и время других.
2. Откладывание выполнения дипломной работы на последний момент.
3. Ожидание моментального ответа на свой вопрос. Дипломные руководители — работающие инженеры, которые занимаются, кроме преподавания, своими проектами. Их время ограничено, поэтому постарайтесь задавать правильные вопросы, чтобы получать быстрые ответы :)
