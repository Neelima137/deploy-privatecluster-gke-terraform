variable "name" {
  type    = string
  default = "test-1"
}
variable "location" {
  type    = string
  default = "us-central1"

}
variable "project" {
  type    = string
  default = <<project-id>>

}
variable "machine_type" {
  type    = string
  default = "e2-medium"

}


