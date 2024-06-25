# adguard-to-elasticsearch
Push AdGuard Home query logs to Elasticsearch

## Goal of this project
The purpose of this project is to propose a solution for sending AdGuard DNS query logs to Elasticsearch. By default, AdGuard Home DNS query logs cannot be forwarded to external services such as syslog server, log collector or forwarder. AdGuard Home creates the query results file locally. In addition, the most important field in this log file is encrypted and cannot be easily verified for details of DNS network traffic.

The ultimate solution for above mentioned issue is to utilize AdGuard Home API (ask AdGuard Home for query logs programatically- the response is not encrypted and can be fully analyzed and investigated) then send the logs to the destination.(Elasticsearch). 

This project does not describe how to install and set up components proposed in order to achieve its goal (excluding configuration files for each component). Instead, it gives a ready-made and tested solution for sending DNS query logs to Elasticsearch. These logs can be filtered, analyzed, and searched. Thanks to presence of AdGuard Home query logs in Elasticsearch the security detection rules can be built to alert on unwanted or suspicious network traffic (attempted or successful). It also gives possibility to create a informative (and even fancy) Kibana dashboards.

## Components and workflow
Four components are neccessary to achive this project goals. Components must be set up and fully operative. Please follow official documentation of each component:
1. [AdGuard Home](https://adguard.com/en/adguard-home/overview.html) instance or instances - a DNS server for assets
2. [n8n](https://n8n.io/) - workflow automation tool - AdGuard Home is programatically and on scheduled queried for DNS query log
3. [fluentbit](https://fluentbit.io/) - logs forwarder - used for basic logs parsing and forwarding to the destination
4. [Elasticsearch](https://www.elastic.co/) - destination for AdGuard Home query logs

Additionally Terraform and [Elasticstack Provider](https://registry.terraform.io/providers/elastic/elasticstack/latest/docs) will be needed to configure Elasticsearch and Kibana.

![diagram](https://github.com/MichalMarchewka/adguard-to-elasticsearch/assets/56821715/8cc05ac2-df98-4770-8176-f0ad8291ae6f)

## Components configuration
The configuration files for n8n, fluentbit and Elasticsearch are part of the repository. Assuming that each component is installed and fully operational (including AdGuard, no configuration is provided), configure the components as follows:
### 1. n8n
AdGuard Home API authentication supports basic authentication only. Credentials used in API requests must be Base64 encoded. In order to create an encoded string, either:
- Use PowerShell:
`$encoded = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("username:password"))|Out-Host`
where `username:password` is credentials used to log in to AdGuard Home
- Encode credentials using [CyberChef](https://gchq.github.io/CyberChef/#recipe=To_Base64('A-Za-z0-9%2B/%3D')): put your `username:password` string in `Input` field and click `BAKE!`

Once you have encoded credentials:
- log into n8n
- in n8n UI navigate to `"Home"` -> `"Credentials"` -> `"Add credentials"`
- from the dropdown list choose `"Header Auth"`
- in `"Name"` field type `Authorization`, in `"Value"` field put your credentials encoded string. Click `"Save"`
- in n8n UI navigate to `"Home"` and click `"Add workflow"`
- click three dots icon in right upper corner and select `"Import from file..."`
- choose `"n8n_workflow.json"`

Workflow should be successfuly imported and visible in n8n UI:

![n8n_workflow](https://github.com/MichalMarchewka/adguard-to-elasticsearch/assets/56821715/661b2b8a-cd10-4a7a-be22-dcecc39bbc31)

- SSH to instance where n8n is installed
- in the home user directory create `adguard_latest_timestamp.txt` file with example content: `2024-06-24T18:46:16.383587612Z`
`echo "2024-06-24T18:46:16.383587612Z" >> /home/ubuntu/adguard_latest_timestamp.txt` - home directory path my vary on the Linux version where n8n is hosted.
This timestamp will be used in the first n8n workflow run. Each next workflow run will update this timestamp to assure logs deduplication
- if timestamp file path is different than presented in the instruction, modify `"Tail file for newest timestamp from previous execution"` and `"Export newest timestamp to the file"` steps in n8n workflow. Simply change the path to the correct one
- modify `"Query AdGuard for DNS query logs"` workflow step. Put correct AdGuard URL and select valid credentials in `"Header Auth"` field- the credentials were created in on of the previous steps
- modify `"Push DNS logs to fluentbit"` workflow step- replace `"fluentbitip"` string with valid fluentbit IP address

### 2. fluentbit
Configure fluent-bit as following:
- SSH to instance where fluentbit is installed
- check if `fluent-bit` service is running. If yes, stop it
- create `input` directory in default fluentbit installation path: `/etc/fluent-bit`
`mkdir input /etc/fluent-bit`
- copy `fluent-bit.conf` into default fluentbit installation path: `/etc/fluent-bit`
- copy `adguard.conf` into newly created `/etc/fluent-bit/input` path
- modify `adguard.conf` file:
    - line 14 - change `dnsserver.domain.tld` to the AdGuard Home FQDN or IP address
    - line 29 - change `elasticsearch.domain.tld` to Elasticsearch FQDN or IP address
    - line 32 - change `password` to `elastic` user password, or other user (if other user is used change also the username in line 31)
note: it is suggested to use `password` value as environmental variable. If the password is exported to environmental variable, the `password` value  in line 32 should be changed to `${VARIABLE_NAME}`

### 3. Elasticsearch
Elasticsearch and Kibana are configured using Terraform and [Elasticstack Provider](https://registry.terraform.io/providers/elastic/elasticstack/latest/docs). Instructions how to install Terraform can be found [here](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli).

Following resources will be created in the Elasticsearch and Kibana using Terraform:
- [Index lifecycle policy](https://www.elastic.co/guide/en/elasticsearch/reference/current/index-lifecycle-management.html)
- [Index template](https://www.elastic.co/guide/en/elasticsearch/reference/current/index-templates.html)
- [Data stream](https://www.elastic.co/guide/en/elasticsearch/reference/current/data-streams.html)
- [Ingest pipeline](https://www.elastic.co/guide/en/elasticsearch/reference/current/ingest.html)
- [Data view](https://www.elastic.co/guide/en/kibana/current/data-views.html)

Once Terraform is installed put `elasticsearch_kibana.tf` file in the directory of your choice. Replace password value in line 14. Set correct Elasticsearch (line 15) and Kibana (line 19) endpoints. Run `terraform init` in that directory. 
note: it is strongly suggested to export Elasticsearch password to environmental variable and use it in the Terraform code. Instruction how to use variables in Terraform can be found [here](https://developer.hashicorp.com/terraform/cli/config/environment-variables)

If Terraform working directory initialization was successful, following output shoud be shown in the console:

![terraform_successful_init](https://github.com/MichalMarchewka/adguard-to-elasticsearch/assets/56821715/6de24d78-72d7-424d-bc4e-68f83c4cca46)

Run `terraform plan` command to see the if no errors are raised. If not, then run `terraform apply --auto-approve` command. The output after succesfful run should be:

![terraform_successful_apply](https://github.com/MichalMarchewka/adguard-to-elasticsearch/assets/56821715/06c2bea8-2e46-4f7f-9360-3f3bdcdeacf1)

## Start streaming logs to Elasticsearch

Two last steps are required to start streaming logs to Elasticsearch:
1. SSH to fluent-bit and enable the `fluent-bit` service
2. Log in to n8n and enable imported workflow

note: n8n workflow is scheduled to run every 5 minutes. 500 records are retrieved from single API call to AdGuard Home. Let the workflow run few times and investigate how many objects are sent to fluent-bit after deduplication. To check this just verify the number of the items like it is presented below:

![n8n_number_of_items_pushed](https://github.com/MichalMarchewka/adguard-to-elasticsearch/assets/56821715/2d0ee092-dd17-492a-be1a-011087f64db1)

If the number of items hits or is really close to hit 500, that means you should consider running the workflow more frequently than every 5 minutes. To change this simply edit the first workflow step, `"Execute Workflow Trigger"`:

![n8n_edit_workflow_tigger](https://github.com/MichalMarchewka/adguard-to-elasticsearch/assets/56821715/001022f5-0f7e-42d0-a764-d36798735750)

Run the workflow manually for the first time.

Now login to Kibana and go to `Discover`, choose `logs-adguard.dns_query` data view. Voila, AdGuard Home DNS query logs are now accessible in Elasticsearch and fields parsing meets [Elastic Common Schema](https://www.elastic.co/guide/en/ecs/current/ecs-reference.html):

![kibana_view](https://github.com/MichalMarchewka/adguard-to-elasticsearch/assets/56821715/7c758719-0d1c-49a2-8055-46fa595dfb90)

## Mappings to ECS fields
|AdGuard log field|ECS field|Custom value|ECS field custom|
|---|---|---|---|
|time|@timestamp||No|
|upstream|destination.domain||No|
|cached|dns.answers.cached||Yes|
|answer_dnssec|dns.answers.dnssec||Yes|
|answer.ttl|dns.answers.ttl||No|
|answer.value|dns.answers.data||No|
|answer.type|dns.answers.type||No|
|question.class|dns.question.class||No|
|question.name|dns.question.name||No|
|question.type|dns.question.type||No|
|status|dns.response.code||No|
||event.action|dns-query|No|
||event.category|network|No|
||event.dataset|adguard.query_log|No|
|elapsedMs|event.duration||No|
|@timestamp|event.ingested||No|
|reason|event.reason||No|
||event.type|connection|No|
|server_domain|server.domain||No|
|client_info.name|source.domain||No|
|client|source.ip||No|

