defmodule OneDriveApi do
  require Logger
  @item_by_id_url "https://api.onedrive.com/v1.0/drive/items/"
  @item_by_path_url "https://api.onedrive.com/v1.0/drive/root:/"

  @auth_url     "https://login.live.com/oauth20_authorize.srf"
  @token_url    "https://login.live.com/oauth20_token.srf"
  @redirect_uri "https://login.live.com/oauth20_desktop.srf"

  @client_id    "7ee18b85-8a43-4fe0-9a44-1b965038d3d4"

  @refresh_token_path "./token.json"

  defmodule OneDriveToken do
    use HTTPoison.Base

    def process_url(url) do
      url
    end

    def process_request_body(body) do
      body
    end

    def process_request_headers(headers) when is_map(headers) do
      Enum.into(headers, [])
    end
  end

  defmodule OneDriveSync do
    use HTTPoison.Base
    def process_request_headers(headers) do
      headers
      |> add_access_token
    end

    def add_access_token(headers) do
      access_token =
        Keyword.get(
          :ets.lookup(:tokens, :access_token), :access_token)
      headers
      |> Keyword.merge([Authorization: access_token])
    end
  end

  defmodule OneDriveSync2 do
    use HTTPoison.Base

    def process_request_headers(access_token) do
      [Authorization: access_token]
    end

    def process_response_headers(headers) do
      headers
      |> Poison.decode!
    end

    def process_response_body(body) do
      unless String.length(body) == 0 do
        body
        |> Poison.decode!
      end
    end
  end

  defmodule OneDriveSync3 do
    use HTTPoison.Base
    def process_request_headers(access_token) do
      [Authorization: access_token]
    end
  end

  def download_by_id(id, path) do
    check_token
    url = "#{@item_by_id_url}#{id}/content?AVOverride=1"
    download(url, path)
  end

  def download(url, path) do
    access_token =
      Keyword.get(:ets.lookup(:tokens, :access_token), :access_token)
    response = OneDriveSync2.get!(url, access_token)

    resource_url =
      response.headers
      |> List.keyfind("Location", 0)
      |> elem(1)

    resource = OneDriveSync3.get!(resource_url, access_token)
    File.write!(path, resource.body)
  end

  def view_changes_by_path(path \\ "", delta_token) do
    check_token

    token =
      case delta_token do
        "" ->
          ""
        _ ->
          "?token=#{delta_token}"
      end

    url =
      "#{@item_by_path_url}#{path}:/view.delta" <>
      "?select=id,name,eTag,cTag,deleted,file," <>
      "folder,fileSystemInfo,remoteItem,parentReference#{token}"

    access_token =
      Keyword.get(:ets.lookup(:tokens, :access_token), :access_token)
    OneDriveSync2.get!(url, access_token)
  end

  def delete_by_id(id, etag) do
    check_token
    url = @item_by_id_url <> id
    headers = unless is_nil(etag) do
      ["If-Match": etag]
    else
      []
    end

    response = OneDriveSync.delete!(url, headers)

    IO.inspect response
  end

  def simple_upload(local_path, remote_path, etag \\ nil) do
    check_token

    stat = File.lstat!(local_path)
    body = File.read!(local_path)
    headers = [
      "Content-Type": "application/octet-stream",
      "Content-Length": stat.size
    ]
    url =
      @item_by_path_url <> URI.encode(remote_path) <> ":/content"
    <> unless is_nil(etag) do
      Keyword.merge(headers, ["If-Match": etag])
      ""
    else
      "?@name.conflictBehavior=fail"
    end

    OneDriveSync.put!(url, body, headers)
  end

  def update_by_id(id, body, ctag \\ nil) do
    check_token

    url = @item_by_id_url <> id

    headers = ["Content-Type": "application/json"]
    unless is_nil(ctag) do
      Keyword.merge(headers, ["If-Match": ctag])
    end

    OneDriveSync.patch!(url, body, headers)
  end

  def create_by_path(parent_path, body) do
    url = @item_by_path_url <> URI.encode(parent_path) <> ":/children"
    headers = ["Content-Type": "application/json"]

    OneDriveSync.post!(url, body, headers)
  end

  def read_token do
    Logger.debug "read_token"
    case File.read(@refresh_token_path) do
      {:ok, refresh_token} ->
        :ets.insert(:tokens, {:refresh_token, refresh_token})
      {:error, _} ->
        authorize
    end
  end

  def authorize do
    auth_url_full =
      "#{@auth_url}?client_id=#{@client_id}" <>
      "&scope=onedrive.readwrite%20offline_access" <>
      "&response_type=code" <>
      "&redirect_uri=#{@redirect_uri}"

    IO.puts "Autorize this app visiging:"
    IO.puts auth_url_full
    response = IO.gets "enter the response uri:"

    String.trim(response)
    |> get_code
    |> redeem_token
  end

  def get_code(response_uri) do
    Regex.run(~r/(?:code=)(([\w\d]+-){4}[\w\d]+)/,response_uri)
    |> tl
    |> hd
    |> validate_code
  end

  def validate_code(code) do
    case String.length(code) do
      0 ->
        Logger.debug "empty code"
      _ ->
        code
    end
  end


  def redeem_token(code) do
    body =
      "client_id=#{@client_id}" <>
      "&redirect_uri=#{@redirect_uri}" <>
      "&code=#{code}" <>
      "&grant_type=authorization_code"

    header = %{"Content-Type": "application/x-www-form-urlencoded"}

    case OneDriveToken.post(@token_url, body, header) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        aquire_token(body)
      {:ok, %HTTPoison.Response{status_code: 400}} ->
        IO.puts "failed."
      {:error, %HTTPoison.Error{reason: reason}} ->
        IO.inspect reason
    end
  end

  def aquire_token(body) do
    tokens = Poison.decode!(body)

    access_token = tokens["token_type"] <> " " <> tokens["access_token"]
    refresh_token = tokens["refresh_token"]
    access_token_expiration = :os.system_time(:seconds) + tokens["expires_in"]

    token_path = Path.absname(@refresh_token_path)
    File.open!(token_path, [:write])
    File.write!(token_path, refresh_token)

    :ets.insert(:tokens, {:access_token, access_token})
    :ets.insert(:tokens, {:refresh_token, refresh_token})
    :ets.insert(:tokens, {:access_token_expiration, access_token_expiration})
  end

  def check_token do
    Logger.debug "check_token"
    expired_time =
      Keyword.get(
        :ets.lookup(
          :tokens, :access_token_expiration), :access_token_expiration)
    if (is_nil(expired_time) ||
      :os.system_time(:seconds) >= expired_time) do
      Logger.debug "token expired"
      new_token
    end
  end

  def new_token do
    Logger.debug "new_token"
    refresh_token =
      Keyword.get(:ets.lookup(:tokens, :refresh_token), :refresh_token)
    body =
      "client_id=#{@client_id}" <>
      "&redirect_uri=#{@redirect_uri}" <>
      "&refresh_token=#{refresh_token}" <>
      "&grant_type=refresh_token"
    header = %{"Content-Type": "application/x-www-form-urlencoded"}

    case OneDriveToken.post(@token_url, body, header) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        aquire_token(body)
      {:ok, %HTTPoison.Response{status_code: 400}} ->
        IO.puts "failed."
      {:error, %HTTPoison.Error{reason: reason}} ->
        IO.inspect reason
    end
  end
end
