variable "subscription_id" {
  description = "ID da assinatura do Azure"
  type        = string
}

variable "synapse_admin_login" {
  description = "Login do administrador do Synapse"
  type        = string
}

variable "synapse_admin_password" {
  description = "Senha do administrador do Synapse"
  type        = string
}

variable "object_id" {
  description = "ID do objeto do usuário atual"
  type        = string
}