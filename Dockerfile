FROM ruby:3.3.6

WORKDIR /usr/src/app

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

ENV PATH="/usr/src/app/bin:${PATH}"

CMD ["/usr/src/app/bin/sync", "--interval"]
