output "neo4j_ui" {
  value = "${aws_instance.neo4j.public_ip}:7474"
}

output "amundsen_ip" {
  value = aws_instance.amundsen.public_ip
}



output "elk_endpoint" {
  value = aws_elasticsearch_domain.es.endpoint
}

output "elk_kibana_endpoint" {
  value = aws_elasticsearch_domain.es.kibana_endpoint
}
