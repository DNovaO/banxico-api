## Cómo ejecutar la build de Docker (PowerShell)

En local uso solo tokens ficticios.

### Imagen base por digest

```powershell
docker pull python:3.12-slim
docker inspect --format='{{index .RepoDigests 0}}' python:3.12-slim
```

El digest se aplica en los dos `FROM` del `Dockerfile`.

**¿Por qué fijo la imagen base por digest?** Porque me permite un build reproducible y
sin cambios inesperados en la base.

**Riesgo:** no recibo parches automáticos y tengo que acordarme de actualizar el digest
de forma manual.

**Qué lo compensa:** el escaneo de Trivy en el pipeline y, en un entorno
real, una herramienta que proponga el cambio y se pueda dejar programada.

### Construir y comprobar

```powershell
docker build -t banxico-api .
docker run --rm banxico-api id
```

Se espera `uid=10001(app)`. Si dice `uid=0`, hay que revisar el `Dockerfile`.

```powershell
$tok = 'a' * 64
docker run -d --rm --name banxico-test -p 8000:8000 -e "BANXICO_TOKEN=$tok" banxico-api
curl.exe localhost:8000/healthz
docker stop banxico-test
```

`/healthz` no llama a Banxico, así que no necesita un token real. La aplicación tarda
unos segundos en responder y Docker marca `(healthy).

### Prueba del token inválido

Si al cargar el secreto en Secrets Manager llega con un espacio o un salto de línea, el
token válido tendría longitud incorrecta, fallaría la validación y quedaría escrito en
CloudWatch. Lo probé con un valor ficticio:

```powershell
docker run --rm -e BANXICO_TOKEN=tokenfalso123 banxico-api
```

Antes, el error incluía el valor: `[type=string_too_short, input_value='tokenfalso123', ...]`.
Lo corregí con `hide_input_in_errors=True` en `config.py`, y tras reconstruir la imagen
queda `[type=string_too_short]`, sin el valor.

Para hacer más robusta la implementación se podría recortar los espacios del token y
usar `SecretStr`, pero lo dejo a nivel de análisis para mantener el código fuente.

### Historial de capas

```powershell
docker history banxico-api --no-trunc
```

No aparece ningún token ni `.env` en las capas.
