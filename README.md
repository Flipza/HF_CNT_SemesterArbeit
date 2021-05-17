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

# 1. Kubernetes Umgebung aufsetzen

## 1.1 Zuerst eine Virtuelle Maschine erstellen

- Cores: 2
- RAM: 4096MB
- Storage: 32GB

## 1.2 Anschliessend kann mit folgender Cloud Init Konfiguration die Kubernetesumgebung erstellt werden:

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
 </pre>

# 2. Dockerfile erstellen
Für meine Semesterarbeit wird nur ein Webserver benötigt und die dafür erstellte Website:
<pre>
FROM php:7.0-apache
RUN mkdir /var/www/html/semesterarbeit
COPY *.css /var/www/html/semesterarbeit/
COPY *.html /var/www/html/semesterarbeit/
</pre>

Anschliessend kann das Dockerimage gebuildet werden und auf Dockerhub raufgeladen werden:
<pre>
sudo docker login
docker build -t flipza/semesterarbeit:V0.1 .
docker push flipza/semesterarbeit:V1.0
</pre>


# 3. Persistenz einrichten
Damit allen Containern nach einem Rebuild alle Daten erhalten bleiben, werden wir persistente Volumes einrichten.
Dies wird auf dem MAAS Controller eingerichtet und darauf zugegriffen:
<pre>
#persistent_volume.yaml
kind: PersistentVolume
apiVersion: v1
metadata:
  name: data-volume
  labels:
    type: local
spec:
  storageClassName: manual
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteMany
  hostPath:
    path: "/data"
</pre>

Für die einzelnen Container wird ein persistent Volume Claim eingerichtet:
<pre>
#pv_claim.yaml
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: data-claim
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 10Gi
</pre>

# 4. Deployment einrichten

Damit mehrere Container erstellt und ein Loadbalancing inklusive ausfallsicherheit sichergestellt ist, wird ein Deployment eingerichtet:
<pre>
#flipza-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  annotations:
  labels:
    app.kubernetes.io/name: semesterarbeit
  name: semesterarbeit
spec:
  replicas: 3
  selector:
    matchLabels:
      app.kubernetes.io/name: semesterarbeit
  template:
    metadata:
      labels:
        app.kubernetes.io/name: semesterarbeit    
    spec:
      containers:
      - image: flipza/semesterarbeit:V0.1
        imagePullPolicy: Always
        name: semesterarbeit
        env:
        - name: DATABASE_HOST
          value: localhost
        - name: DATABASE_USER 
          value: dbuser         
        - name: DATABASE_NAME 
          value: phplogin
        - name: DATABASE_PASS 
          value: PASSWORD
        # Volumes im Container
        volumeMounts:
        - mountPath: "/var/www/html/semesterarbeit/myapp"
          subPath: myapp
          name: "web-storage"
      # Volumes in Host
      volumes:
      - name: web-storage
        persistentVolumeClaim:
          claimName: data-claim
</pre>

# 5. Service konfigurieren
Damit auf die Webapplikation zugegriffen weerden kann, muss die Applikation nach aussen geöffnet werden. Dies wird mit dem Service sichergestellt:
<pre>
#flipza-service.yaml
apiVersion: v1
kind: Service
metadata:
  labels:
    app.kubernetes.io/name: semesterarbeit
  name: semesterarbeit
spec:
  ports:
  - port: 80
    protocol: TCP
    targetPort: 80
  selector:
    app.kubernetes.io/name: semesterarbeit
  type: LoadBalancer
</pre>

# 6. Reverse Proxy
Damit der Service mit einer URL aufgerufen werden kann, benötigen wir einen Reverse Proxy, welcher die Portnummer auf einen Namen Mappt:
<pre>
#flipza-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: semesterarbeit
  labels:
    app: semesterarbeit
spec:
  rules:
  - http:
      paths:
      - path: /semesterarbeit/
        pathType: Prefix
        backend:
          service:
            name: semesterarbeit
            port:
              number: 80
</pre>

# 7. Rolling Update
Um im betrieb ein Applikationsupdate gemacht werden kann, können wir folgendermassen vorgehen:
<pre>
sudo docker login
docker build -t flipza/semesterarbeit:V0.3 .
docker push flipza/semesterarbeit:V0.3
kubectl set image deployment/semesterarbeit semesterarbeit=flipza/semesterarbeit:V0.3
</pre>
