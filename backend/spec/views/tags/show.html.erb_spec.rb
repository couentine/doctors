require 'spec_helper'

describe "tags/show" do
  before(:each) do
    @tag = assign(:tag, stub_model(Tag,
      :name => "Name",
      :name_with_caps => "Name With Caps",
      :wiki => "Wiki",
      :wiki_versions => "",
      :wiki_sections => "",
      :tags => "",
      :tags_with_caps => ""
    ))
  end

  it "renders attributes in <p>" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(/Name/)
    rendered.should match(/Name With Caps/)
    rendered.should match(/Wiki/)
    rendered.should match(//)
    rendered.should match(//)
    rendered.should match(//)
    rendered.should match(//)
  end
end
