FROM alpine:3.6

ENV APP_HOME /app
WORKDIR $APP_HOME
COPY . $APP_HOME

RUN apk update -qq && apk add --no-cache --virtual build-dependencies build-base ruby ruby-dev ruby-json \
    && gem install bundler --no-ri --no-rdoc \
    && bundle install \
    && bundle clean --force  

ENV COMMENT_DATABASE_HOST post_db
ENV COMMENT_DATABASE comments

CMD ["puma"]
