output "webserver_Ip" {
  description = "Web Ip"
  value       = join("", ["http://", aws_instance.First_personal_project.public_ip])
}
output "dbendpoint" {
    description = "Database endpoint: "
    value = module.db.db_instance_endpoint
}
output "dbname" {
    description = "Database name"
    value = module.db.db_instance_name
}
output "dbusername" {
    description = "Databse username"
    value = module.db.db_instance_username
    sensitive = true
}