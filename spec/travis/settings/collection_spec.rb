# frozen_string_literal: true

require 'spec_helper'

describe Travis::Settings::Collection do
  attr_reader :collection_class

  before do
    model_class = Class.new(Travis::Settings::Model) do
      attribute :description

      attribute :id, String
      attribute :secret, Travis::Settings::EncryptedValue
    end

    Travis::Settings.const_set('Foo', model_class)
    @collection_class = Class.new(described_class) do
      model Travis::Settings::Foo
    end
  end

  after do
    Travis::Settings.send(:remove_const, 'Foo')
  end

  it 'loads models from JSON' do
    encrypted = Travis::Settings::EncryptedColumn.new(use_prefix: false).dump('foo')
    json = [{ id: 'ID', description: 'a record', secret: encrypted }]
    collection = collection_class.new
    collection.load(json)
    record = collection.first
    expect(record.id).to eq('ID')
    expect(record.description).to eq('a record')
    expect(record.secret.decrypt).to eq('foo')
  end

  it 'finds class in Travis::Settings namespace' do
    expect(collection_class.model).to eq(Travis::Settings::Foo)
  end

  it 'allows to create a model' do
    SecureRandom.expects(:uuid).returns('uuid')
    collection = collection_class.new
    model = collection.create(description: 'foo')
    expect(model.description).to eq('foo')
    expect(collection.to_a).to eq([model])
    expect(model.id).to eq('uuid')
  end

  describe '#destroy' do
    it 'removes an item from collection' do
      collection = collection_class.new
      item = collection.create(description: 'foo')

      expect(collection.size).to be(1)

      collection.destroy(item.id)

      expect(collection.size).to be(0)
    end
  end

  describe '#find' do
    it 'finds an item' do
      collection = collection_class.new
      item = collection.create(description: 'foo')

      expect(collection.size).to be(1)

      expect(collection.find(item.id)).to eq(item)
      expect(collection.find('foobarbaz')).to be_nil
    end
  end
end
