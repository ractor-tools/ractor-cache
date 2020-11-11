# frozen_string_literal: true

require 'backports/3.0.0/ractor'

require_relative './fixtures'

RSpec.describe Ractor::Cache do
  let(:ape) { Ape.new }

  it 'builds prepended modules' do
    expect(Ape.ancestors).to start_with Ape::RactorCacheLayer, Ape, Mammal, Animal::RactorCacheLayer, Animal
  end

  context 'with "prebuild" strategy' do
    it 'caches simple results correctly' do
      expect(ape.something).to eq [:something]
      expect(ape.something).to eq [:something]
      expect(ape.something_else).to eq [:something, :something_else, %i[something_else refined]]
      expect(ape.something_else).to eq [:something, :something_else, %i[something_else refined]]
      expect(ape.something).to eq [:something]
    end

    it 'prebuilds cache only if need be' do
      ape.freeze
      expect(ape.calls).to be_empty
      Ractor.make_shareable(ape)
      expect(ape.calls).to contain_exactly :something_else, %i[something_else refined], :something
    end
  end

  context 'with "disable" strategy' do
    def complex(arg) # disregard prebuilt cache method calls
      ape.complex(arg)
         .select { |call, _value| call == :complex }
    end

    it 'caches argument-dependent results correctly' do
      expect(ape.complex(42)).to eq [[:complex, 42]]
      expect(ape.complex(42)).to eq [[:complex, 42]]
      expect(ape.complex(-1)).to eq [[:complex, 42], [:complex, -1]]
      expect(ape.complex(-1)).to eq [[:complex, 42], [:complex, -1]]
    end

    it 'uses cache built before being deeply-frozen' do
      ape.freeze
      expect(complex(42)).to eq [[:complex, 42]]
      expect(complex(42)).to eq [[:complex, 42]]
      Ractor.make_shareable(ape)
      expect(complex(42)).to eq [[:complex, 42]]
      expect(complex(-1)).to eq [[:complex, 42], [:complex, -1]]
      expect(complex(-1)).to eq [[:complex, 42], [:complex, -1], [:complex, -1]]
    end
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
      Ractor.make_shareable(nihilist)
      expect(nihilist.simple).to be_nil
      expect(nihilist.complex(42)).to be_nil
      expect(nihilist.complex(-1)).to be_nil
    end
  end
end
