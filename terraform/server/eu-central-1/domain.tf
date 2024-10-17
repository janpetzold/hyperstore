# Configure the Cloudflare provider
provider "cloudflare" {
  email   = var.cloudflare_email
  api_key = var.cloudflare_api_key
}

# Update the CNAME record for hyperstore.cc
resource "cloudflare_record" "hyperstore_cname" {
  zone_id = var.cloudflare_zone_id
  name    = "hyperstore.cc"
  value   = module.ecs_service.alb_dns_name
  type    = "CNAME"
  proxied = true
  allow_overwrite = true
}