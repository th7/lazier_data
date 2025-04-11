# LazierData

The incredible productivity of massive laziness.

LazierData allows splitting, filtering, transforming, batching, and basically everything else you might want to do with data. LazierData processing _looks like_ multiple full iterations of the input data, but under the hood it will process incrementally.

LazierData guarantees each row of input data will be processed by steps in the order the steps are defined. This means not only does LazierData processing _look like_ each step is happening in order, but you can generally think about your data that way.

## Installation

In your Gemfile:
```ruby
source 'https://rubygems.org'
gem 'lazier_data'
```
Then:
`bundle`

## Usage

```ruby
# inputs are anything that can be iterated with .each
lazier = LazierData.new(inputs)

# transform
lazier.enum do |input, clean_inputs|
  clean_inputs << input.except(:unwanted_field)
end

# LazierData uses the parameter name from your previous block
# to allow further processing
# lets filter our clean inputs
lazier[:clean_inputs].enum do |input, filtered_inputs|
  filtered_inputs << input unless input[:skip_me]
end

# let's say our inputs have multiple types
# that need to be handled differently
lazier[:clean_inputs][:filtered_inputs].enum do |input, type_a, type_b|
  case input[:type]
  when :a
  	type_a << input
  when :b
  	type_b << input
  end
end

# LazierData puts the results of your previous steps
# in the corresponding places according to your block params
type_a = lazier[:clean_inputs][:filtered_inputs][:type_a]
type_b = lazier[:clean_inputs][:filtered_inputs][:type_b]

# we can now process each type separately
type_a.each_slice(1000) do |batch_a|
  ModelA.upsert_all(
    batch_a,
    unique_by: %i[unique_field1 unique_field2]
  )
end
type_b.each_slice(1000) do |batch_b|
  ModelB.upsert_all(
    batch_b,
    unique_by: %i[unique_field3 unique_field4]
  )
end

# we can also pull sub items off the inputs
# note that in this example we're taking sub_items from all inputs
# instead of lazier[:clean_inputs][:filtered_inputs].enum do ...
# while it may look like we're reprocessing the entire input list
# under the hood LazierData will pass each item through each step
lazier.enum do |input, sub_items|
  # the below is shorthand for:
  # input[:sub_items].each { |sub_item| sub_items << sub_item }
  input[:sub_items].each(&sub_items)
end

# you can mutate items directly
lazier[:sub_items].each do |sub_item|
  sub_item[:other_data] = fetch_other_data
  sub_item[:mutated] = true
end

# items are guaranteed to have passed through previous steps
# before reaching later steps
lazier[:sub_items].each_slice(1000) do |sub_items|
  if sub_items.any? { |sub_item| !sub_item[:mutated] }
  	# this will never happen :)
  	raise 'LazierData failed me!'
  end

  SubItem.upsert_all(
  	sub_items,
  	unique_by: %i[unique_sub_item_field]
  )
end

# at this point in the code
# none of the above has actually happened
# so, finally, we actually go
lazier.go
```

See [lazier_data_spec.rb](spec/lazier_data_spec.rb) for proven examples.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/better_batch. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/better_batch/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the BetterBatch project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/better_batch/blob/master/CODE_OF_CONDUCT.md).
