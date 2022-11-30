# Red Hat Single SignOn

Este extracto cubre el proceso de instalación del producto **Red Hat Single SignOn 7.4** y sus configuraciones necesarias.

## Detalle de Instalación en GISS

IMPORTANTE: En GISS se hecho la instalación siguiendo los pasos detallados en 'instrucciones.txt'


## Instalacion

1. **Crear el proyecto:**
Primero antes que nada, es necesario crear un proyecto donde vamos ir guardando todos los objetos que sean necesarios para acometer con la instalación propiamente dicha (Imagenes docker, DeploymentConfigs, Rutas, etc).

La creación del proyecto podemos hacerla desde la consola web de OpenShift dirigiendonos al apartado `Home --> Projects` y haciendo clic sobre el boton **Create Project**. Completamos los datos necesarios como el nombre y/o la descripción y concretamos la creacion del mismo con el boton **Create**.

O bien, desde la consola utilizando la herramienta de linea de comandos `oc` y ejecutando el siguiente comando:

```bash
    oc new-project single-signon-noprod
```

> **NOTA:** es importante que el nombre del proyecto sea `single-signon-noprod` porque mas adelante hay comandos que dan por sentado que se usara ese nombre para alojar los objetos de openshift.

2. **Configurar credenciales del repositorio Git**

La generación de la imagen docker y sus configuraciones necesarias se alojan en el repositorio Git para darle seguimiento. Por tanto, el proximo paso es configurar un **Secreto** que contenga las credenciales de acceso a al repositorio Git.

> **NOTA:** Se recomienda de antemano desde la plataforma Gitlab generar un **Access Token** que permita luego autenticar contra la misma. Para ello, desde `Preferences --> Access Tokens` generamos uno y tomamos nota del token generado.

Luego, desde una consola generamos el **Secreto** con el siguiente comando:

```bash
    oc create secret -n single-signon-noprod generic gitlab-basic-auth \
        --from-literal=username=<username> \
        --from-literal=password=<access_token> \
        --type=kubernetes.io/basic-auth

    oc annotate -n single-signon-noprod secret/gitlab-basic-auth \
        'build.openshift.io/source-secret-match-uri-1=http://gitlab.sr.intra.net/*'
```

Es importante notar que con el segundo comando anotamos el **Secreto** con una propiedad que es necesaria para que luego se vincule automaticamente al **BuildConfig** (objeto que genera la imagen docker).

3. **Generar Imagen Docker**

Para automatizar la creacion de la imagen docker resultante que contendra tanto el driver de base de datos especifico y las configuraciones necesarias. Es preciso generar un **BuildConfig** para esto, ejecutamos el siguiente comando:

```bash
    oc -n single-signon-noprod new-build http://gitlab.sr.intra.net/redhat/rhsso.git --name rhsso-sgr --context-dir=. -lapp=sso -lcustom=sgr
```

El proceso que construye la imagen docker (el build) se dispara automaticamente, en caso de que no sea asi, o querramos construir manualmente una nueva imagen con nuevas configuraciones debemos hacerlo manualmente.

> **NOTA:** para disparar el proceso (build), desde la consola web de OpenShift. Nos dirigimos al apartado `Builds --> BuildConfigs`, hacemos clic sobre el icono de los tres puntitos ( ⋮ ) y hacemos clic en la opción **Start build**. Esto generara el proceso que compilará la imagen docker resultante.

4. **Instanciar y/o Deployar Red Hat Single SignOn**

Una vez hayamos generado la imagen docker, es necesario crear un pod y desplegar el producto para que podamos accederlo a través de una URL.

Para esto, necesitamos instanciar el producto a través de un `template`. Para ello, ejecutamos el siguiente comando:

```bash
    oc new-app -n single-signon-noprod --template=sso75-ocp4-x509-https \
        --param=SSO_ADMIN_USERNAME=admin \
        --param=SSO_ADMIN_PASSWORD="redhat01"
```

> **NOTA:** tener en cuenta que en este punto estamos indicandole cuales seran las credenciales para el usuario `administrador`.

Por ultimo, es necesario modificar el objeto `DeploymentConfig` para que en vez de usar la imagen generica y vacía por defecto, en su lugar, use la imagen docker anteriormente creada.

Para esto, nos dirigimos al apartado `Worklodads --> DeploymentConfigs` y hacemos clic sobre el objeto llamado **sso**. Hacemos clic en la pestaña "YAML" y buscamos el siguiente fragmento de codigo:

```yml
spec:
  triggers:
    - type: ImageChange
        from:
          kind: ImageStreamTag
          namespace: single-signon-noprod
          name: 'rhsso-sgr:latest'
  template:
    spec:
      containers:
        - name: sso
          terminationMessagePolicy: File
          image: >-
            image-registry.openshift-image-registry.svc:5000/single-signon-noprod/rhsso-sgr:latest
```

Tener en cuenta que el codigo YAML anterior sirve como referencia. Es decir, debe quedar configurado de esa manera. Originalmente por defecto viene configurado con las imagenes genericas y vacias estandar (`sso75-openshift-rhel8`). Debemos cambiar ese nombre por el nombre de la imagen que generamos anteriormente (`rhsso-sgr`).

No olvidarse hacer clic en el boton **Save** para guardar los cambios una vez terminemos de remplazar los valores.



## Script de ejecución

Se ha creado el script 'install.sh' el cual realiza los paso anteriores de manera automatizada.
Se debe indicar en qué Namespace del cluster se desea realizar la instalación.
Antes de ejecutarlo, revisar los parámetros definidos para verificar que sean correctos:
1. CLUSTER: Cluster donde se va a realizar la instalación
2. CLUSTER_TOKEN: Token de usuario con permisos de admin, para loguearse al cluster (https://CLUSTER/oauth/token/display)

Ejecución:
```bash
    install.sh $NAMESPACE
```