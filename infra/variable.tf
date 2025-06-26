variable "vpc_nb" {
  type = object({
    cidr_bloc = string
    name      = string 
  })
}

variable "subnet" {
  type = map(object({
    cidr_block = string
    name       = string
    type = string
    az = string
  }))
}