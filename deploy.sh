#!/bin/bash
TAG=$1
REGISTRY='registry.8-mega.io'
CONTAINER='/usr/bin/docker'
WORKSPACE='/home/workspace'
NAMESPACE="8-mega-data"
APP="redis"
VERSION='6.2.4-alpine3.13'
APPDIR=$WORKSPACE/$NAMESPACE/$APP
SERVICENAME="svc-redis";
APPPORT=6379;

sudo $CONTAINER pull $APP:$VERSION
sudo $CONTAINER tag $APP:$VERSION $REGISTRY/$NAMESPACE/$APP:$VERSION-$TAG
sudo $CONTAINER push $REGISTRY/$NAMESPACE/$APP:$VERSION-$TAG

# delete existing  kube resources
rm -R $APPDIR/kube.resource.files/*.yaml
kubectl -n $NAMESPACE delete pod $APP
kubectl -n $NAMESPACE delete configmap $APP
kubectl -n $NAMESPACE delete svc $APP

# Create k8s resource  yaml files
cat > $APPDIR/kube.resource.files/$APP-pod.yaml << EOLPODYAML
apiVersion: v1
kind: Pod
metadata:
  name: $APP
  namespace: $NAMESPACE
  labels:
    app: $APP
spec:
  containers:
  - name: $APP-container
    image: $REGISTRY/$NAMESPACE/$APP:$VERSION-$TAG
    command:
      - redis-server
      - "/redis-master/redis.conf"
    env:
    - name: MASTER
      value: "true"
    ports:
    - containerPort: $APPPORT
    resources:
      limits:
        cpu: "0.1"
    volumeMounts:
    - mountPath: /redis-master-data
      name: data
    - mountPath: /redis-master
      name: config
  volumes:
    - name: data
      emptyDir: {}
    - name: config
      configMap:
        name: $APP
        items:
        - key: redis-config
          path: redis.conf
EOLPODYAML
cat > $APPDIR/kube.resource.files/$APP-configmap.yaml << EOLCONFIGMAPYAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: $APP
  namespace: $NAMESPACE
  labels:
    app: $APP
data:
  redis-config: |
    maxmemory 2mb
    maxmemory-policy allkeys-lru 
EOLCONFIGMAPYAML
cat > $APPDIR/kube.resource.files/$APP-svc.yaml << EOLSVCYAML
apiVersion: v1
kind: Service
metadata:
  name: $APP
  namespace: $NAMESPACE
  labels:
    app: $APP
spec:
  type: ClusterIP
  selector:
    app: $APP
 ports:
    - name: $APP-port
      protocol: TCP
      port: $APPPORT
      targetPort: $APPPORT
EOLSVCYAML


# create new kube resources
kubectl create -f $APPDIR/kube.resource.files/$APP-configmap.yaml
kubectl create -f $APPDIR/kube.resource.files/$APP-svc.yaml
kubectl create -f $APPDIR/kube.resource.files/$APP-pod.yaml
