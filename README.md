# spejstore-labelmaker

```sh
bundle install
bundle exec ruby main.rb
```

try it out:

GET http://localhost:4567/api/2/preview.pdf?id=abcdef&name=ItemName&owner=OptionalOwner
POST http://localhost:4567/api/2/print?id=abcdef&name=ItemName&owner=OptionalOwner

Make sure to pass a printer env. See top of `main.rb` for all env variables available.
