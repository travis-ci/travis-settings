describe Travis::Settings do
  it 'returns validations without going through i18n' do
    settings = Class.new(Travis::Settings) {
      attribute :foo, String
      validates :foo, presence: true

      def self.name
        'Test'
      end
    }.new

    settings.foo = nil
    expect(settings).to_not be_valid
    expect(settings.errors[:foo]).to eq(["can't be blank"])
  end

  describe 'adding a setting' do
    let(:settings_class) {
      Class.new(Travis::Settings) {
        attribute :an_integer_field, Integer
        attribute :a_boolean_field, :Boolean, default: true

        def self.name
          'Test'
        end
      }
    }

    it "doesn't allow to set or get unknown settings" do
      settings = settings_class.new
      settings.merge('foo' => 'bar')

      expect(settings.to_hash['foo']).to be_nil
    end

    it 'sets false properly as boolean, not changing it to nil' do
       settings = settings_class.new

      expect(settings.a_boolean_field?).to be true

      settings.a_boolean_field = false
      expect(settings.a_boolean_field?).to be false
    end

    it 'allows to set a property using accessor' do
      settings = settings_class.new

      expect(settings.an_integer_field).to be_nil

      settings.an_integer_field = 1
      expect(settings.an_integer_field).to eq(1)
    end
  end

  describe '#create' do
    let(:settings) {
      model_class = Class.new(Travis::Settings::Model) {
        attribute :name, String
        attribute :repository_id, Integer
      }
      settings_class = Class.new(Travis::Settings) {
        attribute :item, model_class
      }

      settings_class.new
    }

    it 'creates a model for a given key' do
      result = settings.create(:item, name: 'foo')

      expect(settings.item.name).to eq('foo')
      expect(result).to eq(settings.item)
    end

    it 'adds additional attributes to the created model' do
      settings.additional_attributes = { repository_id: 44 }

      settings.create(:item, name: 'foo', repository_id: nil)

      expect(settings.item.name).to eq('foo')
      expect(settings.item.repository_id).to eq(44)
    end
  end

  describe '#update' do
    let(:settings) {
      model_class = Class.new(Travis::Settings::Model) {
        attribute :name, String
      }
      settings_class = Class.new(Travis::Settings) {
        attribute :item, model_class
      }
      settings_class.new
    }

    it 'updates an existing model' do
      settings.load(item: { name: 'foo' })

      expect(settings.item.name).to eq('foo')

      settings.update(:item, name: 'bar')

      expect(settings.item.name).to eq('bar')
    end

    it 'creates a model if it does not exist yet' do
      expect(settings.item).to be_nil

      settings.update(:item, name: 'foo')

      expect(settings.item.name).to eq('foo')
    end
  end

  describe '#delete' do
    it 'removes a model with a given name' do
      model_class = Class.new(Travis::Settings::Model) {
        attribute :name, String
      }
      settings_class = Class.new(Travis::Settings) {
        attribute :item, model_class
      }

      settings = settings_class.new
      settings.load(item: { name: 'foo' })

      expect(settings.item.name).to eq('foo')

      item = settings.item

      result = settings.delete(:item)

      expect(settings.item).to be_nil
      expect(result).to eq(item)
    end
  end

  describe 'simple_attributes' do
    it 'returns only plan attributes' do
      model_class = Class.new(Travis::Settings::Model) {
        attribute :name, String
      }
      collection_class = Class.new(Travis::Settings::Collection) {
        model model_class
      }
      settings_class = Class.new(Travis::Settings) {
        attribute :items, collection_class
        attribute :item, model_class
        attribute :secret, Travis::Settings::EncryptedValue
        attribute :plain, String
      }

      settings = settings_class.new

      settings.load({ items: [{ name: 'foo'}],
                      item: { name: 'bar' },
                      secret: Travis::Settings::EncryptedValue.new('baz'),
                      plain: 'yup' })

      expect(settings.items.first.name).to eq('foo')
      expect(settings.item.name).to eq('bar')
      expect(settings.secret.decrypt).to eq('baz')

      expect(settings.simple_attributes).to eq({ plain: 'yup' })
    end
  end

  describe 'registering a collection' do
    before do
      model_class = Class.new(Travis::Settings::Model) {
        attribute :name, String
      }
      collection_class = Class.new(Travis::Settings::Collection) {
        model model_class
      }
      Travis::Settings.const_set('Items', collection_class)
    end

    after do
      Travis::Settings.send(:remove_const, 'Items')
    end


    it 'allows to register a collection' do
      settings_class = Class.new(Travis::Settings) {
        attribute :items, Travis::Settings::Items.for_virtus
      }
      settings = settings_class.new

      expect(settings.items.to_a).to eq([])
      expect(settings.items.class).to eq(Travis::Settings::Items)
    end

    it 'populates registered collections from raw settings' do
      settings_class = Class.new(Travis::Settings) {
        attribute :items, Travis::Settings::Items.for_virtus
      }

      settings = settings_class.new items: [{ name: 'one' }, { name: 'two' }]
      expect(settings.items.map(&:name)).to eq(['one', 'two'])
    end
  end

  it 'allows to load from nil' do
    settings = Travis::Settings.new(nil)
    settings.to_hash == {}
  end

  describe 'save' do
    it 'runs on_save callback' do
      on_save_performed = false
      settings = Travis::Settings.new('foo' => 'bar').on_save { on_save_performed = true }
      expect(settings.save).to eq(true)

      expect(on_save_performed).to eq(true)
    end

    it 'does not run on_save callback if settings are not valid' do
      on_save_performed = false
      settings = Travis::Settings.new.on_save { on_save_performed = true; }
      settings.stubs(:valid?).returns(false)
      expect(settings.save).to eq(nil)

      expect(on_save_performed).to eq(false)
    end
  end

  describe 'to_hash' do
    it 'returns registered collections and all attributes' do
      model_class = Class.new(Travis::Settings::Model) {
        attribute :id, String
        attribute :name, String
        attribute :content, Travis::Settings::EncryptedValue
      }
      collection_class = Class.new(Travis::Settings::Collection) {
        model model_class
      }
      settings_class = Class.new(Travis::Settings) {
        attribute :items, collection_class.for_virtus
        attribute :first_setting,  String
        attribute :second_setting, String, default: 'second setting default'
        attribute :secret, Travis::Settings::EncryptedValue
      }

      settings = settings_class.new(first_setting: 'a value')
      settings.secret = '44'

      item = settings.items.create(name: 'foo', content: 'bar')

      hash = settings.to_hash

      column = Travis::Settings::EncryptedColumn.new(use_prefix: false)

      expect(hash[:secret]).to_not eq('44')
      expect(column.load(hash[:secret])).to eq('44')

      expect(hash[:first_setting]).to eq('a value')
      expect(hash[:second_setting]).to eq('second setting default')

      hash_item = hash[:items].first
      expect(hash_item[:id]).to eq(item.id)
      expect(hash_item[:name]).to eq('foo')
      expect(hash_item[:content]).to_not eq('bar')
      expect(column.load(hash_item[:content])).to eq('bar')
    end
  end

  describe '#merge' do
    it 'does not save' do
      settings = Travis::Settings.new
      settings.merge(foo: 'bar')
      settings.expects(:save).never
    end

    it 'merges individual fields' do
      settings_class = Class.new(Travis::Settings) {
        attribute :items, Class.new(Travis::Settings::Collection) {
          model Class.new(Travis::Settings::Model) {
            attribute :name, String
          }
        }.for_virtus
        attribute :foo, String
      }
      settings = settings_class.new(foo: 'bar')
      expect(settings.foo).to eq('bar')

      settings.merge('foo' => 'baz', items: [{ name: 'something' }])

      expect(settings.to_hash[:foo]).to eq('baz')
      expect(settings.to_hash[:items]).to eq([])
     end

    it 'does not allow to merge unknown settings' do
      settings = Travis::Settings.new
      settings.merge('possibly_unknown_setting' => 'foo')

      expect(settings.to_hash['possibly_unknown_setting']).to be_nil
    end
  end
end
