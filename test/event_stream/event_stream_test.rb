require_relative '../test_helper'

class EventStreamTest < Minitest::Should::TestCase

  def pub_sub(name_or_event, attrs = {}, filter = nil)
    event = nil
    EventStream.subscribe(filter) do |e|
      event = e
    end
    EventStream.publish(name_or_event, attrs)
    event
  end

  teardown do
    EventStream.default_stream.clear_subscribers
  end

  context 'an event stream' do
    should 'publish an event and allow a subscriber to consume it' do
      event = pub_sub(:test)
      assert event
      assert_equal [:test], event.tags
    end

    should 'allow publishing of pre-constructed events' do
      event = EventStream::Event.new(tags: :test, a: 1)
      subscribed = pub_sub(event)
      assert_equal event, subscribed
    end

    should 'expose all event attributes to the subscriber' do
      event = pub_sub(:test, :x => 1)
      assert_equal 1, event.x
    end

    context 'filtering events' do
      should 'allow subscription to event tags' do
        assert pub_sub(:test, {}, :test)
        refute pub_sub(:test, {}, :other_name)
      end

      should 'allow subscription to event tags by regex' do
        assert pub_sub(:test_event, {}, /test/)
        refute pub_sub(:test_event, {}, /no_match/)
      end

      should 'allow subscription by event attributes' do
        assert pub_sub(:test, { :x => 1, :y => :attr}, :y => :attr)
        refute pub_sub(:test, { :x => 1, :y => :other}, :y => :attr)
      end

      should 'allow subscription via arbitrary predicate' do
        predicate = lambda { |e| e.x > 1 }
        assert pub_sub(:test, { :x => 2, :y => :attr}, predicate)
        refute pub_sub(:test, { :x => 1, :y => :attr}, predicate)
      end

      should 'allow subscription via tags array' do
        assert pub_sub([:a, :b, :c], {}, [:a, :b])
        refute pub_sub([:a, :b, :c], {}, [:d, :e])
      end

    end
  end

  context 'managing multiple event streams' do
    setup do
      @stream = EventStream::Stream.new
      EventStream.register_stream(:test_stream, @stream)
    end

    should 'allow streams to be registered and retrieved' do
      assert_equal @stream, EventStream[:test_stream]
    end

    should 'allow separate publishes and subscriptions to different streams' do
      test_event = nil

      EventStream[:test_stream].subscribe(//) do |e|
        test_event = e
      end

      EventStream[:test_stream].publish(:test_event)
      assert test_event, "Event was expected to be published to the test stream"
      assert test_event.tags.include?(:test_event)

      test_event = nil

      EventStream.publish(:test_event)
      refute test_event, "No event should have been published to the test stream"
    end
  end
end
