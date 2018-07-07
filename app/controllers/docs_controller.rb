class DocsController < ApplicationController
  before_action :set_doc, only: [:show, :edit, :update]
  helper_method :sort_column


  def index
      # i set @docs let it be the complete list of doctors in the main page
    @docs = Doc.all
    if params[:search]
       @docs = Doc.search(params[:search])
     else
       @docs = Doc.all
       @docs = Doc.order(sort_column + " " + sort_direction)
     end
  end


  def show
        # i set @docs let it be the complete list of doctors in the show page
      @docs = Doc.all
          #this line will order each time we click on the title of the tab
      @docs = Doc.order(sort_column + " " + sort_direction)
  end

  def new
    @doc = Doc.new
  end


  def edit
  end

  def create
    @doc = Doc.new(doc_params)

    respond_to do |format|
      if @doc.save
        format.html { redirect_to @doc, notice: 'Doc was successfully created.' }
        format.json { render :show, status: :created, location: @doc }
      else
        format.html { render :new }
        format.json { render json: @doc.errors, status: :unprocessable_entity }
      end
    end
  end


  def update
    respond_to do |format|
      if @doc.update(doc_params)
        format.html { redirect_to @doc, notice: 'Doc was successfully updated.' }
        format.json { render :show, status: :ok, location: @doc }
      else
        format.html { render :edit }
        format.json { render json: @doc.errors, status: :unprocessable_entity }
      end
    end
  end


  private
    # Use callbacks to share common setup or constraints between actions.
    def set_doc
      # i set up @doc to be the one selected
      @doc = Doc.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def doc_params
      params.require(:doc).permit(:name, :speciality, :zip)
    end

# when we lunch the front page it will sort by speciality automaticly
    def sort_column
      params[:sort] || 'specialty'
    end
    # when we lunch the front page it will be an asc sort automaticly

    def sort_direction
      params[:direction] || "asc"
    end

end
