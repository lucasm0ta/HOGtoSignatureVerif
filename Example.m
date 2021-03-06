
image_dir = '../trainingSet/OfflineSignatures/Dutch/TrainingSet/Offline Genuine'; 
data_dir = 'data';

fnames = dir(fullfile(image_dir, '*.PNG'));
num_files = size(fnames,1);
img = cell(num_files,1);
reference = containers.Map;
imSize = [300 550];


hogFeatureSize = 362304;
trainingLabels = cell(num_files,1);
trainingFeatures = zeros(num_files, hogFeatureSize, 'single');
cellSize = [4 4];

for f = 1:num_files
    img{f}.name = fnames(f).name;
    img{f}.path = strjoin({image_dir,'/',img{f}.name},'');
    img{f}.answr = img{f}.name(1:3);
    trainingLabels{f} = img{f}.answr;
    
    im = resizeToFit(rgb2gray(imread(img{f}.path)), imSize);
    img{f}.img = im;
    
    
    th = graythresh(im);
    %imshow(im);
    binaryMask = uint8(im < 255 * th);

    %
    % Linearizar a assinatura e pega o HOG
    im_linear = binaryMask.*255;
    se = strel('ball',3,3);
    im_linear = imdilate(im_linear,se); % Deixar as linhas mais conexas
    im_linear = bwmorph(im_linear,'thin', Inf); % Reduz a linha
    [x,y] = find (im_linear) ;
    CenterOfMass = [mean(x) mean(y)] ;
    %imshow(l);  
    %hold on;
    %plot(CenterOfMassXY(2),CenterOfMassXY(1), 'r*');
    
    img{f}.centroid = CenterOfMass;
    
    if reference.isKey(img{f}.answr)
        orig = img{reference(img{f}.answr)};
        diff = img{f}.centroid - orig.centroid;
         
        T = affine2d([1 0 0; 0 1 0; diff(1) diff(2) 1]);   %# represents translation
        Rin = imref2d(size(orig.img));% Mantem tamanho
        Rin.XWorldLimits = Rin.XWorldLimits-mean(Rin.XWorldLimits);
        Rin.YWorldLimits = Rin.YWorldLimits-mean(Rin.YWorldLimits);
        aux = imwarp(orig.img, Rin, T,'FillValues',255);
        
        %update centroid
        img{f}.centroid = orig.centroid;
        
%         figure
%         imshow(im);
%         figure;
%         imshow(aux);
%         
        
%         featuresOriginal = img{reference(img{f}.answr)}.sift.f;
%         validOriginal = img{reference(img{f}.answr)}.sift.v;
%         index_pairs = matchFeatures(featuresOriginal, features);
%         matchedPtsOriginal  = validOriginal(index_pairs(:,1));
%         matchedPtsDistorted = valid(index_pairs(:,2));
%         [tform,inlierPtsDistorted,inlierPtsOriginal] = estimateGeometricTransform(matchedPtsDistorted,matchedPtsOriginal,...
%         'affine', 'Confidence', 90.0, 'maxdistance', 50);
%         
%         Rin = imref2d(size(im))% Mantem tamanho
%         Rin.XWorldLimits = Rin.XWorldLimits-mean(Rin.XWorldLimits);
%         Rin.YWorldLimits = Rin.YWorldLimits-mean(Rin.YWorldLimits);
%         figure; 
% 
%         showMatchedFeatures(img{f}.img, im,...
%             matchedPtsOriginal,matchedPtsDistorted);
%         im = imwarp(im, Rin, tform,'FillValues', 255);
%         C = imfuse(im, img{f}.img,'falsecolor','Scaling','joint','ColorChannels',[1 2 0]);
%         figure;
%         imshow(C)
    else
         reference(img{f}.answr) = f;
    end
    
    trainingFeatures(f, :) = extractHOGFeatures(im_linear,'CellSize', cellSize);
    %size(trainingFeatures(f, :))
    f
    
    %
    % LBP
%     im = binaryMask.*im;
%     white = uint8(~binaryMask).*255;
%     im = im + white;
% 
%     filtR=generateRadialFilterLBP(8, 1);
%     effLBP= efficientLBP(im, 'filtR', filtR, 'isRotInv', true, 'isChanWiseRot', false);
%     kk = extractHOGFeatures(im, 'CellSize', cellSize);
%     trainingFeatures(f, :) = kk;
%     figure;
%     subplot(1, 3, 1)
%     imshow(im);
%     title('Original image');
% 
%     subplot(1, 3, 2)
%     imshow( effLBP );
%     title('Efficeint LBP image');
end

rng(5); % A titulo de reprodução
mdl = fitcecoc(trainingFeatures, trainingLabels, 'Learners', 'svm');
CVMdl = crossval(mdl); % Cross validation
oofLabel = kfoldPredict(CVMdl);
ConfMat = confusionmat(trainingLabels, oofLabel);

isLabels = unique(trainingLabels);
nLabels = numel(isLabels);
n = size(trainingLabels, 1);
[~,grpOOF] = ismember(oofLabel,isLabels); 
oofLabelMat = zeros(nLabels,n); 
idxLinear = sub2ind([nLabels n],grpOOF,(1:n)'); 
oofLabelMat(idxLinear) = 1; % Flags the row corresponding to the class 
[~,grpY] = ismember(trainingLabels, isLabels); 
YMat = zeros(nLabels,n); 
idxLinearY = sub2ind([nLabels n],grpY,(1:n)'); 
YMat(idxLinearY) = 1; 

figure;
plotconfusion(YMat,oofLabelMat);
%vecs =??;

% rng(5); % A titulo de reprodução
% mdl = fitcecoc(pyramid_all, answr, 'Learners', 'svm');
% CVMdl = crossval(mdl); % Cross validation
% oofLabel = kfoldPredict(CVMdl);
% ConfMat = confusionmat(answr, oofLabel);
% 
% isLabels = unique(answr);
% nLabels = numel(isLabels);
% n = size(answr, 1);
% [~,grpOOF] = ismember(oofLabel,isLabels); 
% oofLabelMat = zeros(nLabels,n); 
% idxLinear = sub2ind([nLabels n],grpOOF,(1:n)'); 
% oofLabelMat(idxLinear) = 1; % Flags the row corresponding to the class 
% [~,grpY] = ismember(answr, isLabels); 
% YMat = zeros(nLabels,n); 
% idxLinearY = sub2ind([nLabels n],grpY,(1:n)'); 
% YMat(idxLinearY) = 1; 
% 
% figure;
% plotconfusion(YMat,oofLabelMat);

function im = resizeToFit(image, mat)
    sz = size(image);
    im = uint8(ones(mat).*255);
    if (sz(1)/mat(1) > sz(2)/mat(2))
        interm = imresize(image, [mat(1) NaN]);
    else
        interm = imresize(image, [NaN mat(2)]);
    end
    im(1:size(interm,1),1:size(interm,2))= interm;
end