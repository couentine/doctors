require 'spec_helper'

describe "tags/new" do
  before(:each) do
    assign(:tag, stub_model(Tag,
      :name => "MyString",
      :name_with_caps => "MyString",
      :wiki => "MyString",
      :wiki_versions => "",
      :wiki_sections => "",
      :tags => "",
      :tags_with_caps => ""
    ).as_new_record)
  end

  it "renders new tag form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", tags_path, "post" do
      assert_select "input#tag_name[name=?]", "tag[name]"
      assert_select "input#tag_name_with_caps[name=?]", "tag[name_with_caps]"
      assert_select "input#tag_wiki[name=?]", "tag[wiki]"
      assert_select "input#tag_wiki_versions[name=?]", "tag[wiki_versions]"
      assert_select "input#tag_wiki_sections[name=?]", "tag[wiki_sections]"
      assert_select "input#tag_tags[name=?]", "tag[tags]"
      assert_select "input#tag_tags_with_caps[name=?]", "tag[tags_with_caps]"
    end
  end
end
