require 'json'
require 'spec_helper'

describe Travis::Settings::Model do
  attr_reader :model_class

  before do
    @model_class = Class.new(described_class) do
      attribute :name
      attribute :loves_travis, :Boolean
      attribute :height, Integer
      attribute :awesome, :Boolean, default: true

      attribute :secret, Travis::Settings::EncryptedValue

      def self.name
        'Test'
      end
    end
  end

  it 'returns a default if it is set' do
    expect(model_class.new.awesome).to be true
  end

  it 'allows to override the default' do
    expect(model_class.new(awesome: false).awesome).to be false
  end

  it 'validates encrypted attributes properly' do
    model_class = Class.new(described_class) do
      attribute :secret, Travis::Settings::EncryptedValue
      validates :secret, presence: true

      def self.name
        'Test'
      end
    end

    model = model_class.new
    expect(model).to_not be_valid
    expect(model.errors[:secret]).to eq(["can't be blank"])
  end

  it 'implements read_attribute_for_serialization method' do
    model = model_class.new(name: 'foo')
    expect(model.read_attribute_for_serialization(:name)).to eq('foo')
  end

  it 'does not coerce nil' do
    model = model_class.new(name: nil)
    expect(model.name).to be nil
  end

  it 'can be loaded from json' do
    encrypted = Travis::Settings::EncryptedColumn.new(use_prefix: false).dump('zażółć gęślą jaźń')
    model = model_class.load(secret: encrypted)
    expect(model.secret.decrypt).to eq('zażółć gęślą jaźń')
  end

  it 'allows to update attributes' do
    model = model_class.new
    model.update(name: 'Piotr', loves_travis: true, height: 178)
    expect(model.name).to eq('Piotr')
    expect(model.loves_travis).to be true
    expect(model.height).to eq(178)
  end

  it 'creates an instance with attributes' do
    model = model_class.new(name: 'Piotr', loves_travis: true, height: 178)
    expect(model.name).to eq('Piotr')
    expect(model.loves_travis).to be true
    expect(model.height).to eq(178)
  end

  it 'allows to overwrite values' do
    model = model_class.new(name: 'Piotr')
    model.name = 'Peter'
    expect(model.name).to eq('Peter')
  end

  it 'coerces values by default' do
    model = model_class.new(height: '178', loves_travis: 'true')
    expect(model.height).to eq(178)
    expect(model.loves_travis).to eq(true)
  end

  it 'allows to override attribute methods' do
    model_class.class_eval do
      def name
        super.upcase
      end
    end

    model = model_class.new(name: 'piotr')
    expect(model.name).to eq('PIOTR')
  end

  it 'handles validations' do
    model_class = Class.new(described_class) do
      attribute :name

      validates :name, presence: true

      def self.name; "Foo"; end
    end

    model = model_class.new
    expect(model).to_not be_valid
    expect(model.errors[:name]).to eq(["can't be blank"])
  end

  describe 'encryption' do
    before do
      @model_class = Class.new(described_class) do
        attribute :secret, Travis::Settings::EncryptedValue
      end
    end

    it 'returns EncryptedValue instance even for nil values' do
      expect(model_class.new.secret).to be_a Travis::Settings::EncryptedValue
    end

    it 'automatically encrypts the data' do
      encrypted_column = Travis::Settings::EncryptedColumn.new(use_prefix: false)
      model = model_class.new secret: 'foo'
      expect(encrypted_column.load(model.secret)).to eq('foo')
      expect(model.secret.decrypt).to eq('foo')

      expect(encrypted_column.load(model.to_hash[:secret].to_s)).to eq('foo')
      expect(encrypted_column.load(JSON.parse(model.to_json)['secret'])).to eq('foo')
    end
  end
end
