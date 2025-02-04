{
  OSM map types & functions.
  Ref.: https://wiki.openstreetmap.org/wiki/Slippy_Map

    based on unit by Simon Kroik, 06.2018, kroiksm@@gmx.de
    which is based on unit openmap.pas
    https://github.com/norayr/meridian23/blob/master/openmap/openmap.pas
    New BSD License

  (c) Fr0sT-Brutal https://github.com/Fr0sT-Brutal/Delphi_OSMMap

  @author(Fr0sT-Brutal (https://github.com/Fr0sT-Brutal))
}
unit OSM.SlippyMapUtils;

{$IFDEF FPC}
  {$MODE Delphi}
{$ENDIF}

interface

uses
  Types, SysUtils, Math;

type
  // Map zoom. 19 = Maximum zoom for Mapnik layer
  TMapZoomLevel = 0..19;

  // Properties of a map tile
  TTile = record
    Zoom: TMapZoomLevel;  // Zoom level
    ParameterX: Cardinal; // Horz number of tile, 0..524288 (=`TileCount(MaxZoom)`)
    ParameterY: Cardinal; // Vert number of tile, 0..524288 (=`TileCount(MaxZoom)`)
  end;
  PTile = ^TTile;

  // Point on a map defined by longitude and latitude.
  // Intentionally not using `TPointF` and `TRectF` because they use other
  // system of coordinates (vertical coord increase from top to down, while latitude changes
  // from +85 to -85)
  TGeoPoint = record
    Long: Double;
    Lat: Double;
    constructor Create(Long, Lat: Double);
  end;

  // Region on a map defined by two pairs of longitude and latitude.
  TGeoRect = record
    TopLeft: TGeoPoint;
    BottomRight: TGeoPoint;
    constructor Create(const TopLeft, BottomRight: TGeoPoint);
    function Contains(const GeoPoint: TGeoPoint): Boolean;
  end;

const
  TILE_IMAGE_WIDTH = 256;   // Width of map tile in pixels
  TILE_IMAGE_HEIGHT = 256;  // Height of map tile in pixels
  // See https://wiki.openstreetmap.org/wiki/Zoom_levels
  TileMetersPerPixelOnEquator: array [TMapZoomLevel] of Double =
  (
    156412,
    78206,
    39103,
    19551,
    9776,
    4888,
    2444,
    1222,
    610.984,
    305.492,
    152.746,
    76.373,
    38.187,
    19.093,
    9.547,
    4.773,
    2.387,
    1.193,
    0.596,
    0.298
  );

//~ configurable globals
var
  // Copyright text
  TilesCopyright: string = '(c) OpenStreetMap contributors';
  // URL of tile server
  MapURLPrefix: string = 'http://tile.openstreetmap.org/';
  // Part of tile URL that goes after tile path
  MapURLPostfix: string = '';
  // Pattern of tile URL. Placeholders are for: Zoom, X, Y
  TileURLPatt: string = '%d/%d/%d.png';

// Construct `TRect` from two `TPoint`-s
function RectFromPoints(const TopLeft, BottomRight: TPoint): TRect; inline;

// Returns count of tiles on `Zoom` level (= `2^Zoom`)
function TileCount(Zoom: TMapZoomLevel): Cardinal; inline;
// Checks `Tile` fields for validity
function TileValid(const Tile: TTile): Boolean; inline;
// Returns standartized string representation of `Tile`
function TileToStr(const Tile: TTile): string;
// Compares tiles
function TilesEqual(const Tile1, Tile2: TTile): Boolean; inline;

// Floor horizontal map coord to tile size
function ToTileWidthLesser(Width: Cardinal): Cardinal; inline;
// Floor vertical map coord to tile size
function ToTileHeightLesser(Height: Cardinal): Cardinal; inline;
// Ceil horizontal map coord to tile size
function ToTileWidthGreater(Width: Cardinal): Cardinal; inline;
// Ceil vertical map coord to tile size
function ToTileHeightGreater(Height: Cardinal): Cardinal; inline;
// Align absolute map rect to tile boundaries
function ToTileBoundary(const Rect: TRect): TRect;

// Returns width of map at zoom level `Zoom` in pixels
function MapWidth(Zoom: TMapZoomLevel): Cardinal; inline;
// Returns height of map at zoom level `Zoom` in pixels
function MapHeight(Zoom: TMapZoomLevel): Cardinal; inline;
// Checks if point `Pt` is inside a map at zoom level `Zoom`
function InMap(Zoom: TMapZoomLevel; const Pt: TPoint): Boolean; overload; inline;
// Checks if rect `Rc` is inside a map at zoom level `Zoom`
function InMap(Zoom: TMapZoomLevel; const Rc: TRect): Boolean; overload; inline;
// Ensures point `Pt` is inside a map at zoom level `Zoom`, corrects values if necessary
// @returns Point that is inside a map
function EnsureInMap(Zoom: TMapZoomLevel; const Pt: TPoint): TPoint; overload; inline;
// Ensures rect `Rc` is inside a map at zoom level `Zoom`, corrects values if necessary
// @returns Rect that is inside a map
function EnsureInMap(Zoom: TMapZoomLevel; const Rc: TRect): TRect; overload; inline;

// Converts geo coord in degrees to map coord in pixels
function LongitudeToMapCoord(Zoom: TMapZoomLevel; Longitude: Double): Cardinal;
// Converts geo coord in degrees to map coord in pixels
function LatitudeToMapCoord(Zoom: TMapZoomLevel; Latitude: Double): Cardinal;
// Converts map coord in pixels to geo coord in degrees
function MapCoordToLongitude(Zoom: TMapZoomLevel; X: Cardinal): Double;
// Converts map coord in pixels to geo coord in degrees
function MapCoordToLatitude(Zoom: TMapZoomLevel; Y: Cardinal): Double;
// Converts map point in pixels to geo point in degrees
function MapToGeoCoords(Zoom: TMapZoomLevel; const MapPt: TPoint): TGeoPoint; overload; inline;
// Converts map rect in pixels to geo rect in degrees
function MapToGeoCoords(Zoom: TMapZoomLevel; const MapRect: TRect): TGeoRect; overload; inline;
// Converts geo point in degrees to map point in pixels
function GeoCoordsToMap(Zoom: TMapZoomLevel; const GeoCoords: TGeoPoint): TPoint; overload; inline;
// Converts geo rect in degrees to map rect in pixels
function GeoCoordsToMap(Zoom: TMapZoomLevel; const GeoRect: TGeoRect): TRect; overload; inline;

// Calculates distance between two geo points in meters
function CalcLinDistanceInMeter(const Coord1, Coord2: TGeoPoint): Double;
// Calculates parameters of map scalebar according to zoom level `Zoom`
procedure GetScaleBarParams(Zoom: TMapZoomLevel;
  out ScalebarWidthInPixel, ScalebarWidthInMeter: Cardinal;
  out Text: string);

// Returns full URL to an image of tile `Tile` using global variables
// MapURLPrefix, TileURLPatt, MapURLPostfix
function TileToFullSlippyMapFileURL(const Tile: TTile): string;

implementation

function RectFromPoints(const TopLeft, BottomRight: TPoint): TRect;
begin
  Result.TopLeft := TopLeft;
  Result.BottomRight := BottomRight;
end;

// Tile utils

function TileCount(Zoom: TMapZoomLevel): Cardinal;
begin
  Result := 1 shl Zoom;
end;

function TileValid(const Tile: TTile): Boolean;
begin
  Result :=
    (Tile.Zoom in [Low(TMapZoomLevel)..High(TMapZoomLevel)]) and
    (Tile.ParameterX < TileCount(Tile.Zoom)) and
    (Tile.ParameterY < TileCount(Tile.Zoom));
end;

function TileToStr(const Tile: TTile): string;
begin
  Result := Format('%d * [%d : %d]', [Tile.Zoom, Tile.ParameterX, Tile.ParameterY]);
end;

function TilesEqual(const Tile1, Tile2: TTile): Boolean;
begin
  Result :=
    (Tile1.Zoom = Tile2.Zoom) and
    (Tile1.ParameterX = Tile2.ParameterX) and
    (Tile1.ParameterY = Tile2.ParameterY);
end;

// Floor value to tile size

function ToTileWidthLesser(Width: Cardinal): Cardinal; inline;
begin
  Result := (Width div TILE_IMAGE_WIDTH)*TILE_IMAGE_WIDTH;
end;

function ToTileHeightLesser(Height: Cardinal): Cardinal; inline;
begin
  Result := (Height div TILE_IMAGE_HEIGHT)*TILE_IMAGE_HEIGHT;
end;

// Ceil value to tile size

function ToTileWidthGreater(Width: Cardinal): Cardinal; inline;
begin
  Result := ToTileWidthLesser(Width);
  if Width mod TILE_IMAGE_WIDTH > 0 then
    Inc(Result, TILE_IMAGE_WIDTH);
end;

function ToTileHeightGreater(Height: Cardinal): Cardinal; inline;
begin
  Result := ToTileHeightLesser(Height);
  if Height mod TILE_IMAGE_HEIGHT > 0 then
    Inc(Result, TILE_IMAGE_HEIGHT);
end;

function ToTileBoundary(const Rect: TRect): TRect;
begin
  Result := TRect.Create(
    // move view rect to the border of tiles (to lesser value)
    ToTileWidthLesser(Rect.Left),
    ToTileHeightLesser(Rect.Top),
    // resize view rect to the border of tiles (to greater value)
    ToTileWidthGreater(Rect.Right),
    ToTileHeightGreater(Rect.Bottom)
  );
end;

function MapWidth(Zoom: TMapZoomLevel): Cardinal;
begin
  Result := TileCount(Zoom)*TILE_IMAGE_WIDTH;
end;

function MapHeight(Zoom: TMapZoomLevel): Cardinal;
begin
  Result := TileCount(Zoom)*TILE_IMAGE_HEIGHT;
end;

function InMap(Zoom: TMapZoomLevel; const Pt: TPoint): Boolean;
begin
  Result := Rect(0, 0, MapWidth(Zoom), MapHeight(Zoom)).Contains(Pt);
end;

function InMap(Zoom: TMapZoomLevel; const Rc: TRect): Boolean;
begin
  Result := Rect(0, 0, MapWidth(Zoom), MapHeight(Zoom)).Contains(Rc);
end;

function EnsureInMap(Zoom: TMapZoomLevel; const Pt: TPoint): TPoint;
begin
  Result := Point(
    Min(Pt.X, MapWidth(Zoom)),
    Min(Pt.Y, MapHeight(Zoom))
  );
end;

function EnsureInMap(Zoom: TMapZoomLevel; const Rc: TRect): TRect;
begin
  Result := RectFromPoints(
    EnsureInMap(Zoom, Rc.TopLeft),
    EnsureInMap(Zoom, Rc.BottomRight)
  );
end;

// Coord checking

procedure CheckValidLong(Longitude: Double); inline;
begin
  Assert(InRange(Longitude, -180, 180));
end;

procedure CheckValidLat(Latitude: Double); inline;
begin
  Assert(InRange(Latitude, -85.1, 85.1));
end;

procedure CheckValidMapX(Zoom: TMapZoomLevel; X: Cardinal); inline;
begin
  Assert(InRange(X, 0, MapWidth(Zoom)));
end;

procedure CheckValidMapY(Zoom: TMapZoomLevel; Y: Cardinal); inline;
begin
  Assert(InRange(Y, 0, MapHeight(Zoom)));
end;

{ TGeoPoint }

constructor TGeoPoint.Create(Long, Lat: Double);
begin
  CheckValidLong(Long);
  CheckValidLat(Lat);
  Self.Long := Long;
  Self.Lat := Lat;
end;

{ TGeoRect }

constructor TGeoRect.Create(const TopLeft, BottomRight: TGeoPoint);
begin
  Self.TopLeft := TopLeft;
  Self.BottomRight := BottomRight;
end;

// If the region contains given point
function TGeoRect.Contains(const GeoPoint: TGeoPoint): Boolean;
begin
  Result :=
    InRange(GeoPoint.Long, TopLeft.Long, BottomRight.Long) and
    InRange(GeoPoint.Lat, BottomRight.Lat, TopLeft.Lat); // !
end;

// Degrees to pixels

function LongitudeToMapCoord(Zoom: TMapZoomLevel; Longitude: Double): Cardinal;
begin
  CheckValidLong(Longitude);

  Result := Floor((Longitude + 180.0) / 360.0 * MapWidth(Zoom));

  CheckValidMapX(Zoom, Result);
end;

function LatitudeToMapCoord(Zoom: TMapZoomLevel; Latitude: Double): Cardinal;
var
  SavePi: Extended;
  LatInRad: Extended;
begin
  CheckValidLat(Latitude);

  SavePi := Pi;
  LatInRad := Latitude * SavePi / 180.0;
  Result := Floor((1.0 - ln(Tan(LatInRad) + 1.0 / Cos(LatInRad)) / SavePi) / 2.0 * MapHeight(Zoom));

  CheckValidMapY(Zoom, Result);
end;

function GeoCoordsToMap(Zoom: TMapZoomLevel; const GeoCoords: TGeoPoint): TPoint;
begin
  Result := Point(
    LongitudeToMapCoord(Zoom, GeoCoords.Long),
    LatitudeToMapCoord(Zoom, GeoCoords.Lat)
  );
end;

function GeoCoordsToMap(Zoom: TMapZoomLevel; const GeoRect: TGeoRect): TRect;
begin
  Result := RectFromPoints(
    GeoCoordsToMap(Zoom, GeoRect.TopLeft),
    GeoCoordsToMap(Zoom, GeoRect.BottomRight)
  );
end;

// Pixels to degrees

function MapCoordToLongitude(Zoom: TMapZoomLevel; X: Cardinal): Double;
begin
  CheckValidMapX(Zoom, X);

  Result := X / MapWidth(Zoom) * 360.0 - 180.0;
end;

function MapCoordToLatitude(Zoom: TMapZoomLevel; Y: Cardinal): Double;
var
  n: Extended;
  SavePi: Extended;
begin
  CheckValidMapY(Zoom, Y);

  SavePi := Pi;
  n := SavePi - 2.0 * SavePi * Y / MapHeight(Zoom);

  Result := 180.0 / SavePi * ArcTan(0.5 * (Exp(n) - Exp(-n)));
end;

function MapToGeoCoords(Zoom: TMapZoomLevel; const MapPt: TPoint): TGeoPoint;
begin
  Result := TGeoPoint.Create(
    MapCoordToLongitude(Zoom, MapPt.X),
    MapCoordToLatitude(Zoom, MapPt.Y)
  );
end;

function MapToGeoCoords(Zoom: TMapZoomLevel; const MapRect: TRect): TGeoRect;
begin
  Result := TGeoRect.Create(
    MapToGeoCoords(Zoom, MapRect.TopLeft),
    MapToGeoCoords(Zoom, MapRect.BottomRight)
  );
end;

// Other

function CalcLinDistanceInMeter(const Coord1, Coord2: TGeoPoint): Double;
var
  Phimean: Double;
  dLambda: Double;
  dPhi: Double;
  Alpha: Double;
  Rho: Double;
  Nu: Double;
  R: Double;
  z: Double;
  Temp: Double;
const
  D2R: Double = 0.017453;
  a: Double = 6378137.0;
  e2: Double = 0.006739496742337;
begin
  dLambda := (Coord1.Long - Coord2.Long) * D2R;
  dPhi := (Coord1.Lat - Coord2.Lat) * D2R;
  Phimean := ((Coord1.Lat + Coord2.Lat) / 2.0) * D2R;

  Temp := 1 - e2 * Sqr(Sin(Phimean));
  Rho := (a * (1 - e2)) / Power(Temp, 1.5);
  Nu := a / (Sqrt(1 - e2 * (Sin(Phimean) * Sin(Phimean))));

  z := Sqrt(Sqr(Sin(dPhi / 2.0)) + Cos(Coord2.Lat * D2R) *
    Cos(Coord1.Lat * D2R) * Sqr(Sin(dLambda / 2.0)));

  z := 2 * ArcSin(z);

  Alpha := Cos(Coord2.Lat * D2R) * Sin(dLambda) * 1 / Sin(z);
  Alpha := ArcSin(Alpha);

  R := (Rho * Nu) / (Rho * Sqr(Sin(Alpha)) + (Nu * Sqr(Cos(Alpha))));

  Result := (z * R);
end;

procedure GetScaleBarParams(Zoom: TMapZoomLevel; out ScalebarWidthInPixel, ScalebarWidthInMeter: Cardinal; out Text: string);
const
  ScalebarWidthInKm: array [TMapZoomLevel] of Double =
  (
    10000,
    5000,
    3000,
    1000,
    500,
    300,
    200,
    100,
    50,
    30,
    10,
    5,
    3,
    1,
    0.500,
    0.300,
    0.200,
    0.100,
    0.050,
    0.020
  );
var
  dblScalebarWidthInMeter: Double;
begin
  dblScalebarWidthInMeter := ScalebarWidthInKm[Zoom] * 1000;
  ScalebarWidthInPixel := Round(dblScalebarWidthInMeter / TileMetersPerPixelOnEquator[Zoom]);
  ScalebarWidthInMeter := Round(dblScalebarWidthInMeter);

  if ScalebarWidthInMeter < 1000 then
    Text := IntToStr(ScalebarWidthInMeter) + ' m'
  else
    Text := IntToStr(ScalebarWidthInMeter div 1000) + ' km'
end;

function TileToFullSlippyMapFileURL(const Tile: TTile): string;
begin
  Result :=
    MapURLPrefix +
    Format(TileURLPatt, [Tile.Zoom, Tile.ParameterX, Tile.ParameterY]) +
    MapURLPostfix;
end;

end.
