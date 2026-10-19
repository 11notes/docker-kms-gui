ARG APP_VERSION=stable
ARG APP_PREFIX=""
ARG APP_SUFFIX=""
ARG APP_UID=1000
ARG APP_GID=1000
ARG BUILD_ROOT=/git/fork-pykms-frontend

FROM 11notes/distroless:localhealth AS distroless-localhealth

# :: Build / styles
  FROM alpine/git AS styles
  ARG APP_NO_CACHE
  ARG BUILD_ROOT
  RUN set -ex; \
    git clone https://github.com/11notes/fork-pykms-frontend.git; \
    cd ${BUILD_ROOT};

# :: Header
  FROM 11notes/kms:${APP_PREFIX}${APP_VERSION}${APP_SUFFIX}

  # :: arguments
    ARG TARGETARCH
    ARG APP_IMAGE
    ARG APP_NAME
    ARG APP_VERSION
    ARG APP_ROOT
    ARG APP_UID
    ARG APP_GID
    ARG APP_NO_CACHE
    ARG BUILD_ROOT

    # :: python image
      ARG PIP_ROOT_USER_ACTION=ignore
      ARG PIP_BREAK_SYSTEM_PACKAGES=1
      ARG PIP_DISABLE_PIP_VERSION_CHECK=1
      ARG PIP_NO_CACHE_DIR=1

  # :: environment
    ENV APP_IMAGE=${APP_IMAGE}
    ENV APP_NAME=${APP_NAME}
    ENV APP_VERSION=${APP_VERSION}
    ENV APP_ROOT=${APP_ROOT}

    ENV KMS_GUI_STYLE="custom-icon"

    ENV PYKMS_SQLITE_DB_PATH=/kms/var/kms.db
    ENV PYKMS_LICENSE_PATH=/opt/py-kms/LICENSE
    ENV PYKMS_VERSION_PATH=/opt/py-kms/VERSION
    ENV PORT=3000
    ENV LOG_LEVEL=INFO

  # :: multi-stage
    COPY ./LICENSE /opt/py-kms

  # :: Run
  USER root
  RUN eleven printenv;

  # :: install application
    RUN set -ex; \
      mkdir -p ${APP_ROOT}/var; \
      cd /opt/py-kms; \
      echo "${APP_VERSION}" > VERSION; \
      echo "master" >> VERSION; \
      uv install -r /opt/py-kms/requirements.gui.txt;

  # :: copy filesystem changes
    COPY ./rootfs /

  # :: add multi template option
    RUN set -ex; \
      mkdir -p ${APP_ROOT}/styles/py-kms; \
      mkdir -p ${APP_ROOT}/styles/custom-icon; \
      cp -R /opt/py-kms/templates ${APP_ROOT}/styles/py-kms; \
      cp -R /opt/py-kms/static ${APP_ROOT}/styles/py-kms; \
      rm -rf /opt/py-kms/templates; \
      rm -rf /opt/py-kms/static; \
      rm -f /usr/local/bin/nc;

    COPY --from=styles ${BUILD_ROOT}/templates ${APP_ROOT}/styles/custom-icon/templates
    COPY --from=styles ${BUILD_ROOT}/static ${APP_ROOT}/styles/custom-icon/static
    COPY --from=distroless-localhealth / /

  # :: set correct permissions
    RUN set -ex; \
      chmod +x -R /usr/local/bin; \
      chown -R ${APP_UID}:${APP_GID} \
        ${APP_ROOT} \
        /opt/py-kms;

# :: Monitor
  HEALTHCHECK --interval=5s --timeout=2s --start-period=5s \
    CMD ["/usr/local/bin/localhealth", "http://localhost:3000/livez"]

# :: Start
  USER ${APP_UID}:${APP_GID}