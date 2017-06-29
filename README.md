## EFK

This docker is integrated with FluentD, ElasticSearch and Kibana

### Purpose:

1. Centralize the log input:
   - Post a json from different send-out log APIs

2. Deliver to many
   - ElasticSearch: monitoring the latest activities
   - MongoDB: store the log
   - S3:  data archive

3. Visualize Activities
   - show the APIs activities

### Command:

`docker-compose up`

### Ports:

5601 -> Kibana

9200 -> ElasticSearch

9527 -> FluentD Input(My preference, you can amend it)

24230 -> FluentD Debug
