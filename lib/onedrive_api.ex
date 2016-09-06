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

    @fields ~w(
      value
      @odata.nextLink
      @odata.deltaLink
      @delta.token
      @odata.context
    )
    @fields_value ~w(
      cTag
      eTag
      file
      fileSystemInfo
      id
      name
      parentReference
    )
    @fields_file_system_info ~w(
      createdDateTime
      lastModifiedDateTime
    )
    @fields_parent_reference ~w(
      driveId
      id
    )
    @fields_file ~w(
      hashes
      mimeType
    )
    @fields_hashes ~w(
      crc32Hash
      sha1Hash
    )

    def process_request_headers(access_token) do
      [Authorization: access_token]
    end

    def process_response_body(body) do
      body = body
      |> Poison.decode!
      |> process_map(@fields)
      |> Keyword.update!(:value, fn(values)
        -> values
        |> Enum.map(fn(value) -> process_value(value) end)
      end)
      IO.inspect body
      body
    end

    def process_map(map, keywords) do
      map
      |> Map.take(keywords)
      |> Enum.map(fn{k, v} -> {String.to_atom(k), v} end)
    end

    def process_value(value) do
      value
      |> process_map(@fields_value)
      |> process_keyword_list(@fields_file_system_info, :fileSystemInfo)
      |> process_keyword_list(@fields_parent_reference, :parentReference)
      |> process_keyword_list(@fields_file, :file)
      |> process_hash
    end

    def process_keyword_list(list, keywords, key) do
      case Keyword.has_key?(list, key) do
        :true ->
          list
          |> Keyword.update!(key, fn(map)
            -> map
            |> process_map(keywords)
          end)
        :false ->
          list
      end
    end

    def process_hash(list) do
      case Keyword.has_key?(list, :file) do
        :true ->
          list[:file]
          |> Keyword.update!(:hashes, fn(map)
            -> map
            |> process_map(@fields_hashes)
          end)
        :false -> list
      end
    end
  end

  def view_changes_by_path(pid, path \\ [], delta_token) do
    pid |> check_token

    delta_token =
      case delta_token do
        "" ->
          delta_token
        _ ->
          "?token=" <> delta_token
      end

    url =
      @item_by_path_url <>
      path <>
      ":/view.delta" <>
      "?select=id,name,eTag,cTag,deleted,file,folder,fileSystemInfo,remoteItem,parentReference" <>
      delta_token

    OneDriveSync.get!(url, TokensServer.get(pid, :access_token))
  end

  def read_token(pid) do
    Logger.debug "read_token"
    case File.read(@refresh_token_path) do
      {:ok, refresh_token} ->
        TokensServer.put(pid, :refresh_token, refresh_token)
      {:error, _} ->
        authorize(pid)
    end
  end

  def authorize(pid) do
    auth_url_full =
      @auth_url <>
      "?client_id=" <> @client_id <>
      "&scope=onedrive.readwrite%20offline_access" <>
      "&response_type=code" <>
      "&redirect_uri=" <> @redirect_uri

    IO.puts "Autorize this app visiging:"
    IO.puts auth_url_full
    response = IO.gets "enter the response uri:"

    code = String.trim(response)
    |> get_code

    redeem_token(code, pid)
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
        IO.puts "empty"
      _ ->
        code
    end
  end


  def redeem_token(code, pid) do
    body =
      "client_id=" <> @client_id <>
      "&redirect_uri=" <> @redirect_uri <>
      "&code=" <> code <>
      "&grant_type=authorization_code"

    header = %{"Content-Type": "application/x-www-form-urlencoded"}

    case OneDriveToken.post(@token_url, body, header) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        aquire_token(body, pid)
      {:ok, %HTTPoison.Response{status_code: 400}} ->
        IO.puts "failed."
      {:error, %HTTPoison.Error{reason: reason}} ->
        IO.inspect reason
    end
  end

  def aquire_token(body, pid) do
    tokens = Poison.decode!(body)

    access_token = tokens["token_type"] <> " " <> tokens["access_token"]
    refresh_token = tokens["refresh_token"]
    access_token_expiration = :os.system_time(:seconds) + tokens["expires_in"]

    token_path = Path.absname(@refresh_token_path)
    File.open!(token_path, [:write])
    File.write!(token_path, refresh_token)

    TokensServer.put(pid, :access_token, access_token)
    TokensServer.put(pid, :refresh_token, refresh_token)
    TokensServer.put(pid, :access_token_expiration, access_token_expiration)
  end

  def check_token(pid) do
    Logger.debug "check_token"
    expired_time = TokensServer.get(pid, :access_token_expiration)
    if (is_nil(expired_time) ||
      :os.system_time(:seconds) >= expired_time) do
      Logger.debug "token expired"
      new_token(pid)
    end
  end

  def new_token(pid) do
    Logger.debug "new_token"
    body =
      "client_id=" <> @client_id <>
      "&redirect_uri=" <> @redirect_uri <>
      "&refresh_token=" <> TokensServer.get(pid, :refresh_token) <>
      "&grant_type=refresh_token"
    header = %{"Content-Type": "application/x-www-form-urlencoded"}

    case OneDriveToken.post(@token_url, body, header) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        aquire_token(body, pid)
      {:ok, %HTTPoison.Response{status_code: 400}} ->
        IO.puts "failed."
      {:error, %HTTPoison.Error{reason: reason}} ->
        IO.inspect reason
    end
  end
end
