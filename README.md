# Ractor::Cache

## Usage:

```ruby
# Typical cached method:
class Foo
  def long_calc
    @long_calc ||= do_long_calculation
  end
end

# With Ractor::Cache:
using Ractor::Cache

class Foo
  cache def long_calc
    do_long_calculation
  end
end
```

## Why?

0) It's pretty
1) Handles `nil` / `false` results
2) Works even for frozen instances
3) Works even for deeply frozen instances (`Ractor`-shareable).

## `Ractor`-shareable?

Ractor is new in Ruby 3.0 and is awesome.

Passing classes between Ractors can be done very efficiently if classes are deeply frozen.

For some classes, being frozen isn't useful or possible (e.g. `IO`), but for many it is possible.

One challenge of writing classes that can be deeply frozen is methods that cache the results:

```ruby
f = Foo.new
f.freeze
f.long_calc # => FrozenError, can't set `@long_calc`
```

Some techniques could include storing the cache in a mutable data structure:

```ruby
class Foo
  def initialize
    @cache = {}
  end

  def long_calc
    @cache[:long_calc] ||= # ...
  end
end

f = Foo.new
f.freeze
f.long_calc # => ok
```

But `Ractor.make_shareable` freezes the instance variables too, so this can't work:

```ruby
f = Foo.new
Ractor.make_shareable(foo)
foo.long_calc # => `FrozenError`, @cache is frozen
```

## How to resolve this

This gem will use associate a mutable data structure to the instance. Even if deeply-frozen it can still mutate the data structure. The data is Ractor-local, so it won't be shared and won't cause issues. Internally a `WeakMap` is used to make sure objects are still garbage collected as they should.

Implementation details [explained here](hacker_guide.md)

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/marcandre/ractor-cache. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/marcandre/ractor-cache/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Ractor::Cache project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/marcandre/ractor-cache/blob/master/CODE_OF_CONDUCT.md).
