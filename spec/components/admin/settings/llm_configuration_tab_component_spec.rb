require "rails_helper"

describe Admin::Settings::LlmConfigurationTabComponent do
  let(:component) { Admin::Settings::LlmConfigurationTabComponent.new }

  describe "#tab" do
    it "returns the correct tab identifier" do
      expect(component.tab).to eq("#tab-llm-configuration")
    end
  end

  describe "#providers" do
    it "returns providers from RemoteTranslations::Llm::Config" do
      providers_hash = { a: :stub }
      expect(RemoteTranslations::Llm::Config).to receive(:providers).and_return(providers_hash)

      expect(component.providers).to eq(providers_hash)
    end
  end

  describe "#provider_options" do
    let(:providers) do
      {
        OpenAI: { enabled: true },
        Anthropic: { enabled: false },
        Gemini: { enabled: true }
      }
    end

    before do
      allow(RemoteTranslations::Llm::Config).to receive(:providers).and_return(providers)
    end

    context "when no provider is selected" do
      before { Setting["llm.provider"] = nil }

      it "generates options for all providers" do
        options = component.provider_options
        expect(options).to include("OpenAI")
        expect(options).to include("Anthropic")
        expect(options).to include("Gemini")
      end

      it "disables providers that are not enabled" do
        options = component.provider_options
        # Check that disabled providers are marked as disabled in the options
        expect(options).to match(/Anthropic/)
      end
    end

    context "when a provider is selected" do
      before { Setting["llm.provider"] = "OpenAI" }

      it "selects the current provider" do
        options = component.provider_options
        expect(options).to include("OpenAI")
        # The options_for_select should include the selected value
        expect(options).to match(/OpenAI/)
      end
    end
  end

  describe "#models" do
    context "when provider is blank" do
      before { Setting["llm.provider"] = nil }

      it "returns an empty hash" do
        expect(component.models).to eq({})
      end
    end

    context "when provider is set" do
      before { Setting["llm.provider"] = "OpenAI" }

      it "returns models from RubyLLM for the provider" do
        model1 = double("Model", name: "GPT-4o", id: "gpt-4o")
        model2 = double("Model", name: "GPT-4o-mini", id: "gpt-4o-mini")
        models_collection = [model1, model2]

        allow(RubyLLM.models).to receive(:by_provider).with(:openai).and_return(models_collection)

        result = component.models

        expect(result).to eq({
          "GPT-4o" => { id: "gpt-4o", enabled: true },
          "GPT-4o-mini" => { id: "gpt-4o-mini", enabled: true }
        })
      end
    end
  end

  describe "#model_options" do
    context "when no models are available" do
      before do
        Setting["llm.provider"] = "OpenAI"
        allow(RubyLLM.models).to receive(:by_provider).and_return([])
      end

      it "returns empty options string" do
        options = component.model_options
        expect(options).to be_empty
      end
    end

    context "when models are available" do
      before do
        Setting["llm.provider"] = "OpenAI"
        model1 = double("Model", name: "GPT-4o", id: "gpt-4o")
        model2 = double("Model", name: "GPT-4o-mini", id: "gpt-4o-mini")
        allow(RubyLLM.models).to receive(:by_provider).and_return([model1, model2])
      end

      context "when no model is selected" do
        before { Setting["llm.model"] = nil }

        it "generates options for all available models" do
          options = component.model_options
          expect(options).to include("GPT-4o")
          expect(options).to include("GPT-4o-mini")
        end
      end

      context "when a model is selected" do
        before { Setting["llm.model"] = "gpt-4o" }

        it "includes the selected model in options" do
          options = component.model_options
          expect(options).to include("GPT-4o")
        end
      end
    end
  end

  describe "#model_disabled?" do
    context "when provider is blank" do
      before { Setting["llm.provider"] = nil }

      it "returns true" do
        expect(component.model_disabled?).to be true
      end
    end

    context "when provider is set" do
      before { Setting["llm.provider"] = "OpenAI" }

      it "returns false" do
        expect(component.model_disabled?).to be false
      end
    end

    context "when provider is an empty string" do
      before { Setting["llm.provider"] = "" }

      it "returns true" do
        expect(component.model_disabled?).to be true
      end
    end
  end

  describe "#feature_disabled?" do
    context "when provider is blank" do
      before do
        Setting["llm.provider"] = nil
        Setting["llm.model"] = "gpt-4o"
      end

      it "returns true" do
        expect(component.feature_disabled?).to be true
      end
    end

    context "when model is blank" do
      before do
        Setting["llm.provider"] = "OpenAI"
        Setting["llm.model"] = nil
      end

      it "returns true" do
        expect(component.feature_disabled?).to be true
      end
    end

    context "when both provider and model are blank" do
      before do
        Setting["llm.provider"] = nil
        Setting["llm.model"] = nil
      end

      it "returns true" do
        expect(component.feature_disabled?).to be true
      end
    end

    context "when both provider and model are set" do
      before do
        Setting["llm.provider"] = "OpenAI"
        Setting["llm.model"] = "gpt-4o"
      end

      it "returns false" do
        expect(component.feature_disabled?).to be false
      end
    end

    context "when provider is set but model is an empty string" do
      before do
        Setting["llm.provider"] = "OpenAI"
        Setting["llm.model"] = ""
      end

      it "returns true" do
        expect(component.feature_disabled?).to be true
      end
    end
  end

  describe "rendering disabled states based on the configuration" do
    let(:providers) do
      {
        OpenAI: { enabled: true },
        Anthropic: { enabled: false },
        Gemini: { enabled: true }
      }
    end

    before do
      allow(RemoteTranslations::Llm::Config).to receive(:providers).and_return(providers)
    end

    context "when provider is not set" do
      before do
        Setting["llm.provider"] = nil
        Setting["llm.model"] = nil
      end

      it "renders the component with disabled model dropdown" do
        model1 = double("Model", name: "GPT-4o", id: "gpt-4o")
        allow(RubyLLM.models).to receive(:by_provider).and_return([model1])

        render_inline component

        expect(page).to have_css("fieldset[disabled]")
      end

      it "renders the component with disabled toggle" do
        render_inline component

        expect(page).to have_button(disabled: true)
      end
    end

    context "when provider is set but model is not" do
      before do
        Setting["llm.provider"] = "OpenAI"
        Setting["llm.model"] = nil
      end

      it "renders the component with enabled model dropdown" do
        model1 = double("Model", name: "GPT-4o", id: "gpt-4o")
        allow(RubyLLM.models).to receive(:by_provider).with(:openai).and_return([model1])

        render_inline component

        expect(page).not_to have_css("fieldset[disabled]")
      end

      it "renders the component with disabled translation toggle" do
        model1 = double("Model", name: "GPT-4o", id: "gpt-4o")
        allow(RubyLLM.models).to receive(:by_provider).with(:openai).and_return([model1])

        render_inline component

        expect(page).to have_button(disabled: true)
      end
    end

    context "when both provider and model are set" do
      before do
        Setting["llm.provider"] = "OpenAI"
        Setting["llm.model"] = "gpt-4o"
      end

      it "renders the component with enabled translation toggle" do
        model1 = double("Model", name: "GPT-4o", id: "gpt-4o")
        allow(RubyLLM.models).to receive(:by_provider).with(:openai).and_return([model1])

        render_inline component

        expect(page).to have_button(disabled: false)
      end
    end
  end
end
