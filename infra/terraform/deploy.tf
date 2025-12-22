data "archive_file" "app_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../app"
  output_path = "/tmp/aztek-weather-app.zip"
}

resource "null_resource" "deploy_app" {
  depends_on = [azurerm_linux_web_app.web]

  triggers = {
    zip_sha = data.archive_file.app_zip.output_sha
  }

  provisioner "local-exec" {
    command = <<EOT
      az webapp deploy \
        --resource-group ${azurerm_resource_group.rg.name} \
        --name ${azurerm_linux_web_app.web.name} \
        --src-path ${data.archive_file.app_zip.output_path} \
        --type zip
    EOT
    interpreter = ["bash", "-lc"]
  }
}