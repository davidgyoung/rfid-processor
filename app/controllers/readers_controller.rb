class ReadersController < ApplicationController
  before_action :set_reader, only: [:show, :edit, :update, :destroy]
  skip_before_action :verify_authenticity_token, if: :json_request?

  # GET /readers
  # GET /readers.json
  def index
    @readers = Reader.all
  end

  # GET /readers/1
  # GET /readers/1.json
  def show
  end

  # GET /readers/new
  def new
    @reader = Reader.new
  end

  # GET /readers/1/edit
  def edit
  end

  # POST /readers
  # POST /readers.json
  #curl -X POST http://localhost:3000/readers -H "accept: application/json" -H "content-type: application/json" --data '{"reader":{"name":"y", "mac_address":"01:02:03:04:05:06", "tags":[{"tag_id":"y", "utid":"z", "rssi":"-75", "antenna":"1", "last_seen_at":"2015-01-01"}]}}'
  def create
    logger.debug "looking up by mac: #{reader_params[:mac_address]}"
    @reader = Reader.find_by(mac_address: reader_params[:mac_address])
    if @reader
      logger.debug "Existing reader: #{@reader}"
    else
      @reader = Reader.new(reader_params)
    end
    success = @reader.save
    puts "Tag params are #{tags_params}"
    if success      
      Tag.where(reader: @reader).each{|tag| tag.visible = false; tag.save! }
      success = true
      tag = nil      
      if tags_params[:tags]
        tags_params[:tags].each do |tag_hash|
          tag = Tag.find_by(tag_id: tag_hash[:tag_id], reader: @reader)
          if tag
            puts "updating tag from  from #{tag_hash}"          
            success = tag.update(tag_hash.merge(visible: true))
          else
            puts "creating tag from  from #{tag_hash}"          
            tag = Tag.new(tag_hash)
            tag.reader = @reader
            tag.visible = true
            success &= tag.save        
          end
          break unless success
        end
      end
    end

    respond_to do |format|
      if success
        format.html { redirect_to @reader, notice: 'Reader was successfully created.' }
        format.json { render action: 'show', status: :created, location: @reader }
      else
        format.html { render action: 'new' }
        format.json { render json: @reader.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /readers/1
  # PATCH/PUT /readers/1.json
  def update
    respond_to do |format|
      if @reader.update(reader_params)
        format.html { redirect_to @reader, notice: 'Reader was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @reader.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /readers/1
  # DELETE /readers/1.json
  def destroy
    @reader.destroy
    respond_to do |format|
      format.html { redirect_to readers_url }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_reader
      @reader = Reader.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def reader_params
      params.require(:reader).permit(:name, :description, :mac_address, :ip_address, 
                                     :version, :model, :last_updated_at)
    end

    def tags_params
      params.require(:reader).permit({:tags => [:tag_id, :rssi, :antenna, :last_seen_at, :utid]})
    end

    
  protected
    def json_request?
      puts "is this a json request? #{request.format.json?}, #{request.headers["Content-Type"]}"
      true # request.format.json?
    end
end
