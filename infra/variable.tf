variable "vpc_nb" {
  type = object({
    cidr_bloc = string
    name      = string
  })
}

variable "subnet" {
  type = map(object({
    cidr_block = string
    type       = string
    az         = string
  }))
}

variable "db_credentials" {
  type = object({
    username = string
  })
  sensitive = true
}
