%% grafico_curvado_radio.m
% MATLAB R2024a
clear; clc; close all;

%% ---------------- configuracion ----------------
xlsxFile = 'grafica_radio.xlsx';

imgCandidates = {'CURVA2.png','CURVA2.PNG'};
imgFile = '';
for k = 1:numel(imgCandidates)
    if isfile(imgCandidates{k})
        imgFile = imgCandidates{k};
        break
    end
end

if isempty(imgFile)
    error('No se encuentra CURVA.png ni CURVA.PNG en la carpeta actual.');
end

if ~isfile(xlsxFile)
    error('No se encuentra grafica_radio.xlsx en la carpeta actual.');
end

% Tus datos van de derecha a izquierda
DATA_RIGHT_TO_LEFT = true;

% Altura visual maxima del grafico
MAX_CHART_HEIGHT_PX = 95;

% Paso de la escala derecha
TICK_STEP = 0.4;

% Etiquetas manuales de contouring. Dejalo [] para reparto automatico.
MANUAL_LABEL_VALUES = [55 53 50 48 45];

N_AUTO_LABELS   = 5;
LABEL_OFFSET_PX = 12;
TITLE_OFFSET_PX = 42;

%% ---------------- leer imagen ----------------
I = imread(imgFile);
[hImg, wImg, ~] = size(I);

%% ---------------- extraer curva azul de la imagen ----------------
R = double(I(:,:,1));
G = double(I(:,:,2));
B = double(I(:,:,3));

maskBlue = (B > 120) & ((B - R) > 40) & ((B - G) > 10);

[rowBlue, colBlue] = find(maskBlue);

if isempty(colBlue)
    error('No se ha detectado la curva azul en la imagen.');
end

xCurveImg = (min(colBlue):max(colBlue)).';
yCurveImg = nan(size(xCurveImg));

for k = 1:numel(xCurveImg)
    xk = xCurveImg(k);
    yy = rowBlue(colBlue == xk);
    if ~isempty(yy)
        yCurveImg(k) = median(double(yy));
    end
end

idxValid = isfinite(yCurveImg);
yCurveImg = interp1(xCurveImg(idxValid), yCurveImg(idxValid), xCurveImg, 'pchip', 'extrap');
yCurveImg = smoothdata(yCurveImg, 'movmean', 9);

%% ---------------- leer excel ----------------
T = readtable(xlsxFile, 'VariableNamingRule', 'preserve');
varNames = T.Properties.VariableNames;

idxContour = find(contains(lower(varNames), 'contour'), 1);
idxContact = find(contains(lower(varNames), 'contact'), 1);

numMask = varfun(@isnumeric, T, 'OutputFormat', 'uniform');
numIdx = find(numMask);

if isempty(idxContour)
    if isempty(numIdx)
        error('No se ha encontrado ninguna columna numerica para contouring.');
    end
    idxContour = numIdx(1);
end

if isempty(idxContact)
    if numel(numIdx) < 2
        error('No se ha encontrado una segunda columna numerica para Contact.');
    end
    idxContact = numIdx(2);
end

contouring = double(T{:, idxContour});
contact    = double(T{:, idxContact});

contouring = contouring(:);
contact    = contact(:);

ok = isfinite(contouring) & isfinite(contact);
contouring = contouring(ok);
contact    = contact(ok);

if numel(contact) < 2
    error('No hay suficientes datos validos en grafica_radio.xlsx.');
end

if max(contact) <= 0
    error('La columna Contact no tiene valores positivos validos.');
end

%% ---------------- invertir orden ----------------
if DATA_RIGHT_TO_LEFT
    contouring = flipud(contouring);
    contact    = flipud(contact);
end

n = numel(contact);

if max(abs(contouring)) <= 1.5
    contourPercent = 100 * contouring;
else
    contourPercent = contouring;
end

%% ---------------- muestrear curva base ----------------
sCurve = linspace(0, 1, numel(xCurveImg)).';
sData  = linspace(0, 1, n).';

xBase = interp1(sCurve, xCurveImg, sData, 'pchip');
yBase = interp1(sCurve, yCurveImg, sData, 'pchip');

xBase = xBase(:);
yBase = yBase(:);
contact = contact(:);

%% ---------------- construir grafico curvado SIN inclinar alturas ----------------
% La altura se mide en vertical, no sobre la normal
pxPerMm = MAX_CHART_HEIGHT_PX / max(contact);

xTop = xBase;
yTop = yBase - contact .* pxPerMm;

xTop = xTop(:);
yTop = yTop(:);

xPoly = [xBase; flipud(xTop)];
yPoly = [yBase; flipud(yTop)];

%% ---------------- niveles de la escala derecha ----------------
tickMax  = ceil(max(contact) / TICK_STEP) * TICK_STEP;
tickVals = (0:TICK_STEP:tickMax).';

nTicks = numel(tickVals);

xGridCell = cell(nTicks,1);
yGridCell = cell(nTicks,1);
xGridEnd  = zeros(nTicks,1);
yGridEnd  = zeros(nTicks,1);

for i = 1:nTicks
    off = tickVals(i) * pxPerMm;

    % Curvas paralelas por desplazamiento vertical
    xGrid = xBase;
    yGrid = yBase - off;

    xGridCell{i} = xGrid;
    yGridCell{i} = yGrid;

    xGridEnd(i) = xGrid(end);
    yGridEnd(i) = yGrid(end);
end

xAxisRight = max(xBase) + 40;

%% ---------------- figura ----------------
figure('Color', 'w', 'Position', [80 80 max(wImg, round(xAxisRight + 90)) hImg]);
ax = axes('Position', [0 0 1 1]);

image(ax, I);
axis(ax, 'image');
axis(ax, 'ij');
axis(ax, 'off');
hold(ax, 'on');

%% ---------------- area curvada ----------------
patch(ax, xPoly, yPoly, [0.27 0.57 0.87], ...
    'EdgeColor', 'none', ...
    'FaceAlpha', 0.88);

%% ---------------- rejilla curvada ----------------
for i = 1:nTicks
    plot(ax, xGridCell{i}, yGridCell{i}, ...
        'Color', [0.68 0.68 0.68], ...
        'LineWidth', 0.8);
end

%% ---------------- contornos del grafico ----------------
plot(ax, xBase, yBase, ...
    'Color', [0.18 0.45 0.78], ...
    'LineWidth', 2.1);

plot(ax, xTop, yTop, ...
    'Color', [0.18 0.45 0.78], ...
    'LineWidth', 1.0);

%% ---------------- eje derecho y conectores ----------------
for i = 1:nTicks
    plot(ax, [xGridEnd(i), xAxisRight], [yGridEnd(i), yGridEnd(i)], ...
        'Color', [0.35 0.35 0.35], ...
        'LineWidth', 0.8);
end

plot(ax, [xAxisRight xAxisRight], [yGridEnd(end) yGridEnd(1)], ...
    'k', 'LineWidth', 1.1);

for i = 1:nTicks
    plot(ax, [xAxisRight-5, xAxisRight], [yGridEnd(i), yGridEnd(i)], ...
        'k', 'LineWidth', 1.0);

    text(ax, xAxisRight + 8, yGridEnd(i), sprintf('%.1f', tickVals(i)), ...
        'HorizontalAlignment', 'left', ...
        'VerticalAlignment', 'middle', ...
        'FontSize', 11, ...
        'Color', 'k');
end

text(ax, xAxisRight + 38, mean([yGridEnd(1), yGridEnd(end)]), 'Contact (mm)', ...
    'Rotation', 90, ...
    'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'middle', ...
    'FontSize', 12, ...
    'Color', 'k');

%% ---------------- titulo superior ----------------
allGridY = cell2mat(yGridCell);
yTitle = max(28, min([yTop; allGridY]) - TITLE_OFFSET_PX);

text(ax, mean(xBase), yTitle, '% contouring', ...
    'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'middle', ...
    'FontSize', 13, ...
    'Color', 'k');

%% ---------------- etiquetas de contouring ----------------
if isempty(MANUAL_LABEL_VALUES)
    idxLab = round(linspace(1, n, N_AUTO_LABELS));
else
    idxLab = zeros(numel(MANUAL_LABEL_VALUES),1);
    for k = 1:numel(MANUAL_LABEL_VALUES)
        [~, idxLab(k)] = min(abs(contourPercent - MANUAL_LABEL_VALUES(k)));
    end
    idxLab = unique(idxLab, 'stable');
end

for k = 1:numel(idxLab)
    i = idxLab(k);

    xLab = xBase(i);
    yLab = yBase(i) - LABEL_OFFSET_PX;

    text(ax, xLab, yLab, sprintf('%.0f%%', contourPercent(i)), ...
        'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'middle', ...
        'FontSize', 12, ...
        'Color', 'w');
end

%% ---------------- limites ----------------
xlim(ax, [1, xAxisRight + 85]);
ylim(ax, [1, hImg]);

%% ---------------- exportar ----------------
exportgraphics(ax, 'grafico_curvado.png', 'Resolution', 300);
disp('Figura guardada como: grafico_curvado2.png');