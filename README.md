# spejstore-labelmaker

```sh
bundle install
bundle exec ruby main.rb
```

try it out:

GET http://localhost:4567/api/1/preview/:label.png
GET http://localhost:4567/api/1/preview/:label.pdf
POST http://localhost:4567/api/1/print/:label

where :label is a `spejstore` label.id or item.short_id

to test without spejstore running locally, pass:

```sh
LABELMAKER_DEBUG_JSON='{"short_id":"abcdef","name":"Some long test item","owner":"testowner"}' bundle exec ruby main.rb
```

