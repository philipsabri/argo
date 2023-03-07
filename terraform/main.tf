terraform {
  required_providers {
    argocd = {
      source  = "oboukili/argocd"
      version = "4.3.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.8.0"
    }
  }
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

provider "argocd" {
  server_addr = "localhost:30080"
  username    = "admin"
  password    = "password"
  insecure    = true
}

resource "helm_release" "argocd" {
  name             = "argo-cd"
  chart            = "argo-cd"
  repository       = "https://argoproj.github.io/argo-helm"
  create_namespace = true
  namespace        = "argocd"
  set {
    name  = "server.service.type"
    value = "NodePort"
  }
  set {
    name  = "configs.secret.argocdServerAdminPassword"
    value = "$2a$10$hOZuN7xCjETqmuD8.wDMIu/y1VNJYlbKD.kkUOKohhgBwRF0i6JoC"
  }
}

resource "argocd_repository" "infra-argo" {
  repo            = "https://github.com/philipsabri/argocd.git"
  depends_on      = [helm_release.argocd]
}

resource "argocd_application" "app-of-apps" {
  depends_on = [argocd_repository.infra-argo]
  metadata {
    name      = "app-of-apps"
    namespace = "argocd"
  }

  spec {
    source {
      repo_url        = argocd_repository.infra-argo.repo
      path            = "app-of-apps"
      target_revision = "main"
    }

    destination {
      server    = "https://kubernetes.default.svc"
      namespace = "default"
    }

    sync_policy {
      automated = {
        prune       = true
        self_heal   = true
        allow_empty = true
      }
      retry {
        limit = "5"
        backoff = {
          duration     = "30s"
          max_duration = "2m"
          factor       = "2"
        }
      }
    }
  }
}
