require 'spec_helper'

describe "tags/index" do
  before(:each) do
    assign(:tags, [
      stub_model(Tag,
        :name => "Name",
        :name_with_caps => "Name With Caps",
        :wiki => "Wiki",
        :wiki_versions => "",
        :wiki_sections => "",
        :tags => "",
        :tags_with_caps => ""
      ),
      stub_model(Tag,
        :name => "Name",
        :name_with_caps => "Name With Caps",
        :wiki => "Wiki",
        :wiki_versions => "",
        :wiki_sections => "",
        :tags => "",
        :tags_with_caps => ""
      )
    ])
  end

  it "renders a list of tags" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => "Name".to_s, :count => 2
    assert_select "tr>td", :text => "Name With Caps".to_s, :count => 2
    assert_select "tr>td", :text => "Wiki".to_s, :count => 2
    assert_select "tr>td", :text => "".to_s, :count => 2
    assert_select "tr>td", :text => "".to_s, :count => 2
    assert_select "tr>td", :text => "".to_s, :count => 2
    assert_select "tr>td", :text => "".to_s, :count => 2
  end
end
