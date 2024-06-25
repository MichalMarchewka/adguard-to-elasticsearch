terraform {
    required_version = ">= 1.0.0"
    required_providers {
        elasticstack = {
            source  = "elastic/elasticstack"
            version = "0.11.4"
        }
    }
}

provider "elasticstack" {
    elasticsearch {
        username  = "elastic"
        password  = "password"
        endpoints = ["https://elasticsearch.domain.tld:9200"]
        insecure = false
    }
    kibana {
        endpoints = ["https://kibana.domain.tld:5601"]
        insecure = false
    }
}

resource "elasticstack_elasticsearch_index_lifecycle" "logs_adguard_dns_query" {
  name = "logs-adguard.dns_query"

  hot {
    min_age = "1h"
    set_priority {
      priority = 10
    }
    rollover {
      max_age = "7d"
    }
    readonly {}
  }

  delete {
    min_age = "90d"
    delete {}
  }
}

resource "elasticstack_elasticsearch_index_template" "logs_adguard_dns_query" {
  name = "logs-adguard.dns_query"

  index_patterns = ["logs-adguard.dns_query*"]

  template {
    settings = jsonencode({
      "lifecycle.name" = "logs-adguard.dns_query"
      "default_pipeline" = "logs-adguard.dns_query"
    })
    mappings = jsonencode({
      dynamic = false
      properties = {
        "destination" = {
          properties = {
            "domain" = { type = "keyword" }
          }
        }
        "client" = {
          properties = { 
            "domain" = { type = "keyword" }
            "ip" = { type = "ip" }
          }
        }
        "dns" = {
          properties = {
            "question" = {
              properties = {
                "name" = { type = "keyword" }
                "class" = { type = "keyword" }
                "type" = { type = "keyword" }
              }
            }
            "answers" = {
              properties = {
                "data" = { type = "keyword" }
                "dnssec" = { type = "boolean" }
                "ttl" = { type = "keyword" }
                "type" = { type = "keyword" }
                "cached" = { type = "boolean" }
              }
            }
            "resolved_ip" = { type = "ip" }
            "response_code" = { type = "keyword" } 
          }
        }
        "event" = {
          properties = {
            "action" = { type = "keyword" }
            "category" = { type = "keyword" }
            "dataset" = { type = "keyword" }
            "duration" = { type = "long" }
            "ingested" = { type = "date" }
            "reason" = { type = "keyword" }
            "type" = { type = "keyword" }
          }
        }
        "geo" = {
          properties = {
            "city_name" = { type = "keyword" }
            "continent_name" = { type = "keyword" }
            "country_iso_code" = { type = "keyword" }
            "country_name" = { type = "keyword" }
            "region_iso_code" = { type = "keyword" }
            "region_name" = { type = "keyword" }
            "location" = { type = "geo_point" }
          }
        }
        "server" = {
          properties = {
            "domain" = { type = "keyword" }
          }
        }
      }
    })
  }
  data_stream {}
}

resource "elasticstack_elasticsearch_data_stream" "logs_adguard_dns_query" {
  name = "logs-adguard.dns_query"

  depends_on = [
    elasticstack_elasticsearch_index_template.logs_adguard_dns_query
  ]
}

resource "elasticstack_elasticsearch_ingest_pipeline" "logs_adguard_dns_query" {
  name        = "logs-adguard.dns_query"
  description = "Ingest pipeline logs-adguard.dns_query"
  processors = [
    jsonencode({
        set = {
            field = "event.ingested"
            copy_from = "@timestamp"
            ignore_failure = false
            ignore_empty_value = true
        }
    }),
    jsonencode({
        set = {
            field = "@timestamp"
            copy_from = "time"
            ignore_failure = false
            ignore_empty_value = true
        }
    }),
    jsonencode({
        remove = {
            field = "time"
        }
    }),
    jsonencode({
        set = {
            field = "event.action"
            value = "dns-query"
            ignore_failure = false
            ignore_empty_value = true
        }
    }),
    jsonencode({
        set = {
            field = "event.category"
            value = "network"
            ignore_failure = false
            ignore_empty_value = true
        }
    }),
    jsonencode({
        set = {
            field = "event.dataset"
            value = "adguard.query_log"
            ignore_failure = false
            ignore_empty_value = true
        }
    }),
    jsonencode({
        set = {
            field = "event.duration"
            copy_from = "elapsedMs"
            ignore_failure = false
            ignore_empty_value = true
        }
    }),
    jsonencode({
        remove = {
            field = "elapsedMs"
        }
    }),
    jsonencode({
        set = {
            field = "event.reason"
            copy_from = "reason"
            ignore_failure = false
            ignore_empty_value = true
        }
    }),
    jsonencode({
        remove = {
            field = "reason"
        }
    }),
    jsonencode({
        set = {
            field = "event.type"
            value = "connection"
            ignore_failure = false
            ignore_empty_value = true
        }
    }),
    jsonencode({
        rename = {
            field = "client"
            target_field = "client_temporary"
        }
    }),
    jsonencode({
        set = {
            field = "client.domain"
            copy_from = "client_info.name"
            ignore_failure = false
            ignore_empty_value = true
        }
    }),
    jsonencode({
        remove = {
            field = "client_info.name"
        }
    }),
    jsonencode({
        set = {
            field = "client.ip"
            copy_from = "client_temporary"
            ignore_failure = false
            ignore_empty_value = true
        }
    }),
    jsonencode({
        remove = {
            field = "client_temporary"
        }
    }),
    jsonencode({
        set = {
            field = "dns.question.name"
            copy_from = "question.name"
            ignore_failure = false
            ignore_empty_value = true
        }
    }),
    jsonencode({
        remove = {
            field = "question.name"
        }
    }),
    jsonencode({
        set = {
            field = "dns.question.class"
            copy_from = "question.class"
            ignore_failure = false
            ignore_empty_value = true
        }
    }),
    jsonencode({
        remove = {
            field = "question.class"
        }
    }),
    jsonencode({
        set = {
            field = "dns.question.type"
            copy_from = "question.type"
            ignore_failure = false
            ignore_empty_value = true
        }
    }),
    jsonencode({
        remove = {
            field = "question.type"
        }
    }),
    jsonencode({
        foreach = {
            field = "answer"
            processor = {
                append = {
                    field = "dns.answers.ttl"
                    value = "{{_ingest._value.ttl}}"
                }
            }
            ignore_failure = true
        }
    }),
    jsonencode({
        foreach = {
            field = "answer"
            processor = {
                append = {
                    field = "dns.answers.type"
                    value = "{{_ingest._value.type}}"
                }
            }
            ignore_failure = true
        }
    }),
    jsonencode({
        foreach = {
            field = "answer"
            processor = {
                append = {
                    field = "dns.answers.data"
                    value = "{{_ingest._value.value}}"
                }
            }
            ignore_failure = true
        }
    }),
    jsonencode({
        remove = {
            field = "answer"
            ignore_failure = true
        }
    }),
    jsonencode({
        set = {
            field = "dns.answers.cached"
            copy_from = "cached"
            ignore_failure = false
            ignore_empty_value = true
        }
    }),
    jsonencode({
        remove = {
            field = "cached"
            ignore_failure = true
        }
    }),
    jsonencode({
        set = {
            field = "dns.answers.dnssec"
            copy_from = "answer_dnssec"
            ignore_failure = false
            ignore_empty_value = true
        }
    }),
    jsonencode({
        remove = {
            field = "answer_dnssec"
            ignore_failure = true
        }
    }),
    jsonencode({
        set = {
            field = "dns.response_code"
            copy_from = "status"
            ignore_failure = false
            ignore_empty_value = true
        }
    }),
    jsonencode({
        remove = {
            field = "status"
        }
    }),
    jsonencode({
        set = {
            field = "destination.domain"
            copy_from = "upstream"
            ignore_failure = false
            ignore_empty_value = true
        }
    }),
    jsonencode({
        remove = {
            field = "upstream"
        }
    }),
    jsonencode({
        set = {
            field = "server.domain"
            copy_from = "server_domain"
            ignore_failure = false
            ignore_empty_value = true
        }
    }),
    jsonencode({
        remove = {
            field = "server_domain"
        }
    }),
    jsonencode({
        remove = {
            field = "client_info.disallowed"
        }
    }),
    jsonencode({
        remove = {
            field = "client_info.disallowed_rule"
        }
    }),
    jsonencode({
        remove = {
            field = "client_proto"
        }
    }),
    jsonencode({
        geoip = {
            field = "dns.answers.data"
            target_field = "geo"
            first_only = false
            ignore_failure = true
        }
    })
  ]
}
