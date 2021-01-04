# frozen_string_literal: true

require_relative './fixtures'

def deep_freeze(obj)
  if defined?(Ractor.current)
    Ractor.make_shareable(obj)
  else
    obj.freeze
  end
end

RSpec.describe Ractor::Cache do
  let(:ape) { Ape.new }

  it 'builds prepended modules' do
    expect(Ape.ancestors).to start_with Ape::RactorCacheLayer, Ape, Mammal, Animal::RactorCacheLayer, Animal
  end

  it 'caches simple results correctly' do
    expect(ape.something).to eq [:something]
    expect(ape.something).to eq [:something]
    expect(ape.something_else).to eq [:something, :something_else, %i[something_else refined]]
    expect(ape.something_else).to eq [:something, :something_else, %i[something_else refined]]
    expect(ape.something).to eq [:something]
  end

  it 'works on deeply frozen instances' do
    expect(ape.calls).to be_empty
    deep_freeze(ape)
    expect(ape.calls).to be_empty
    expect(ape.something).to eq [:something]
    expect(ape.something_else).to eq [:something, :something_else, %i[something_else refined]]
    expect(ape.calls).to contain_exactly :something_else, %i[something_else refined], :something
  end

  context 'with results `nil`' do
    let(:nihilist) { Nihilist.new }
    it 'caches them properly' do
      nihilist.simple
      nihilist.simple
      nihilist.complex(42)
      nihilist.complex(-1)
      nihilist.complex(42)
      expect(nihilist.calls).to eq %i[simple complex complex]
    end

    it 'is shareable' do
      nihilist.simple
      nihilist.complex(42)
      deep_freeze(nihilist)
      expect(nihilist.simple).to be_nil
      expect(nihilist.complex(42)).to be_nil
      expect(nihilist.complex(-1)).to be_nil
    end
  end
end

RSpec.describe 'simple api' do
  let(:obj) { SimpleApiExample.new }

  it 'works even if frozen' do
    $called = 0
    deep_freeze(obj)
    expect(obj.foo).to eq 1
    expect(obj.foo).to eq 1
    expect($called).to eq 1
    expect(obj.send(:ractor_cache)).to eq({foo: 1})
  end
end
