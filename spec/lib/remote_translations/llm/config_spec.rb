require "rails_helper"

describe RemoteTranslations::Llm::Config do
  describe ".context" do
    before { stub_secrets(llm: { openai_api_key: "1234" }) }
    it "creates a context with tenant secrets without errors" do
      config = instance_double(RubyLLM::Configuration)
      expect(config).to receive(:openai_api_key=).with("1234")
      context = double("RubyLLM::Context", config: config)
      expect(RubyLLM).to receive(:context).and_yield(config).and_return(context)
      expect { RemoteTranslations::Llm::Config.context }.not_to raise_error
    end
  end

  describe ".providers" do
    before do
      dummy_provider = Class.new do
        def self.configured?(_config)
          true
        end
      end
      stub_const("RubyLLM::Providers::OpenAI", dummy_provider)
    end
    it "maps provider enabled status using RubyLLM providers" do
      context = double("RubyLLM::Context", config: instance_double(RubyLLM::Configuration))
      allow(RemoteTranslations::Llm::Config).to receive(:context).and_return(context)
      allow(RubyLLM::Providers).to receive(:constants).and_return([:OpenAI])
      providers = RemoteTranslations::Llm::Config.providers
      expect(providers).to eq({ OpenAI: { enabled: true }})
    end
  end

  describe "evaluates provider configuration across different tenants" do
    before do
      stub_secrets(
        llm: {
          openai_api_key: "1234"
        },
        tenants: {
          new_tenant_name: {
            llm: {
              deepseek_api_key: "1234",
              openrouter_api_key: "1234"
            }
          }
        }
      )
    end

    it "enables OpenAI for the default tenant" do
      allow(Tenant).to receive(:current_schema).and_return("public")
      providers = RemoteTranslations::Llm::Config.providers

      expect(providers.dig(:DeepSeek, :enabled)).to be false
      expect(providers.dig(:OpenRouter, :enabled)).to be false
      expect(providers.dig(:OpenAI, :enabled)).to be true
    end

    it "enables DeepSeek for the new_tenant_name tenant" do
      allow(Tenant).to receive(:current_schema).and_return("new_tenant_name")
      providers = RemoteTranslations::Llm::Config.providers

      expect(providers.dig(:DeepSeek, :enabled)).to be true
      expect(providers.dig(:OpenRouter, :enabled)).to be true
      expect(providers.dig(:OpenAI, :enabled)).to be false
    end
  end
end
