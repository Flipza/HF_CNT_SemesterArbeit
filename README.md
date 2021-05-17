# HF_CNT_SemesterArbeit

## Die wichtigsten kubectl-Subkommandos in der Übersicht

• kubectl cluster-info – Liefert Informationen zum K8s Cluster

• kubectl run name --image=image – startet ein Container (ähnlich docker run))

• kubectl expose – öffnet Port gegen aussen)

• kubectl get [all] [-o yaml] – zeigt Ressourcen, in unterschiedlichen Formaten, an

• kubectl create -f YAML – Erstellt eine Ressource laut YAML Datei/Verzeichnis )

• kubectl apply –f YAML – führt die Änderungen in der YAML im Cluster nach

• kubectl delete -f YAML – Löscht eine Ressource laut YAML Datei/Verzeichnis

### Eine Shell in einem laufenden container öffnen

- kubectl exec --stdin --tty NameOfContainer -- /bin/bash

## Kubernetes Umgebung aufsetzen

# Zuerst eine Virtuelle Maschine erstellen

- Cores: 2
- RAM: 4096MB
- Storage: 32GB

# Anschliessend kann mit folgender Cloud Init Konfiguration die Kubernetesumgebung erstellt werden:

<pre>
#cloud-config
users:
  - name: ubuntu
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: users, admin
    home: /home/ubuntu
    shell: /bin/bash
    lock_passwd: false
    plain_text_passwd: 'password'        
# login ssh and console with password
ssh_pwauth: true
disable_root: false    
packages:
  - unzip
runcmd:
  - sudo snap install microk8s --classic --channel=1.19
  - sudo usermod -a -G microk8s ubuntu
  - sudo microk8s enable dns ingress 
  - sudo mkdir -p /home/ubuntu/.kube
  - sudo chown -f -R ubuntu /home/ubuntu/.kube
  - sudo microk8s config >/home/ubuntu/.kube/config
  - sudo snap install kubectl --classic 
  - sh -c "echo 'deb http://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_18.04/ /' | sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list"
  - wget -nv https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable/xUbuntu_18.04/Release.key -O /tmp/Release.key
  - sudo apt-key add - </tmp/Release.key
  - sudo apt-get update -qq
  - sudo apt-get -qq -y install buildah 
  - sudo mkdir /data
  - sudo chmod 777 /data
  - sudo apt-get install -y nfs-common
  - sudo mount -t nfs 10.0.42.8:/data/storage /data 
  - sudo microk8s kubectl apply -f https://raw.githubusercontent.com/mc-b/APP_ServiceTool/main/persistentvolume.yaml
  - sudo microk8s kubectl apply -f https://raw.githubusercontent.com/mc-b/APP_ServiceTool/main/persistentvolumeclaim.yaml
  - sudo apt-get -qq -y install fuse-overlayfs
  - </pre>

