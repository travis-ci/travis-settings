# frozen_string_literal: true

require 'spec_helper'

describe Travis::DefaultSettings do
  let(:settings) do
    klass = Class.new(Travis::Settings) do
      include Travis::DefaultSettings

      attribute :foo, String, default: 'bar'
    end
    klass.new
  end

  describe 'getting properties' do
    it 'fetches a given path from default settings' do
      expect(settings.foo).to eql 'bar'
    end
  end

  it "doesn't allow to merge anything" do
    expect { settings.merge({}) }.to raise_error(/merge is not supported/)
  end

  it "doesn't allow to set any values" do
    expect { settings.foo = 'bar' }.to raise_error(/setting values is not supported/)
  end
end
