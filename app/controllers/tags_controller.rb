class TagsController < ApplicationController
  before_action :set_tag, only: [:show, :edit, :update, :destroy]
  skip_before_action :verify_authenticity_token, if: :json_request?

  # GET /tags
  # GET /tags.json
  def index
    @tags = Tag.all
  end

  # GET /tags/1
  # GET /tags/1.json
  def show
  end

  # GET /tags/new
  def new
    @tag = Tag.new
  end

  # GET /tags/1/edit
  def edit
  end

  # POST /tags
  # POST /tags.json
  def create
  
    # special case for multiple tags
    tags = params["_json"]
    if (tags.class.name == 'Array')
      Tag.delete_all
      puts "this is an array"
      success = true
      @tag = nil      
      tags.each do |tag_hash|
        puts "params are going from #{tag_hash} to #{tag_in_array_params(tag_hash)}"
        @tag = Tag.new(tag_in_array_params(tag_hash))
        success &= @tag.save        
        break unless success
      end
      respond_to do |format|
        if success
          format.json { render action: 'show', status: :created, location: @tag }
        else
          format.json { render json: @tag.errors, status: :unprocessable_entity }
        end
      end
      return 
    else 
      puts "class is #{tags.class}"
    end
  
    @tag = Tag.new(tag_params)

    respond_to do |format|
      if @tag.save
        format.html { redirect_to @tag, notice: 'Tag was successfully created.' }
        format.json { render action: 'show', status: :created, location: @tag }
      else
        format.html { render action: 'new' }
        format.json { render json: @tag.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /tags/1
  # PATCH/PUT /tags/1.json
  def update
    respond_to do |format|
      if @tag.update(tag_params)
        format.html { redirect_to @tag, notice: 'Tag was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @tag.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /tags/1
  # DELETE /tags/1.json
  def destroy
    @tag.destroy
    respond_to do |format|
      format.html { redirect_to tags_url }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_tag
      @tag = Tag.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def tag_params
      params.require(:tag).permit(:tag_id, :rssi, :antenna, :last_seen_at)
    end
    
    def tag_in_array_params(hash)
      hash.permit(:tag_id, :rssi, :antenna, :last_seen_at, :utid)
    end

  protected
    def json_request?
      puts "is this a json request? #{request.format.json?}, #{request.headers["Content-Type"]}"
      true # request.format.json?
    end
end
