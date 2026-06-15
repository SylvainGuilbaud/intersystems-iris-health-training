# ========= Base IRIS =========
ARG IMAGE=containers.intersystems.com/intersystems/iris:latest-em
FROM $IMAGE

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHON_PATH=/usr/irissys/bin/ \
    PATH="/usr/irissys/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/irisowner/bin:/home/irisowner/.local/bin"

COPY key/iris.key /usr/irissys/mgr/iris.key

WORKDIR /home/irisowner/dev
COPY . /home/irisowner/dev/

RUN iris start IRIS && \
	iris merge IRIS merge.cpf && \
	iris session IRIS < iris.script && \
	iris stop IRIS quietly