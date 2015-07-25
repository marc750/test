%% Initialisation du programme de trading
% Chargement des données selon la fréquence frequency
% Choix du nombre de devises par portefeuille pour la stratégie HML
% Choix de la mise de départ à investir
clear all; clc;

fprintf('Trading algorithm initialization...\n');
load market_data_monthly;
frequency=12;
fprintf('\tData frequency\t: %3.2f (days)\n', 360/frequency);
nb_cur_by_pf=5;
fprintf('\tHML parameter\t: %i currency(ies) by portfolio\n', nb_cur_by_pf);
ON_rates = dataset2cell(deposit_rates);
[DATA_LEN, NB_CUR] = size(ON_rates);           
DATA_LEN = DATA_LEN-1;                         
pf_cur_ew_mom = ON_rates(1,:);
fprintf('\tEW parameter\t: %i currency(ies) vs. USD\n', length(pf_cur_ew_mom)-1);
ON_rates(1,:) = [];
pf_dates = Date;
pf_cur_hml = cell(DATA_LEN, nb_cur_by_pf*2);
pf_cur_hml_low = cell(DATA_LEN, nb_cur_by_pf);
pf_cur_hml_high = cell(DATA_LEN, nb_cur_by_pf);
portfolios_pos = zeros(DATA_LEN, 3);
pf_HML = zeros(DATA_LEN, 6);  % 1=PnL 2=Pos 3=Rend
pf_EW = zeros(DATA_LEN, 6);   % 1=PnL 2=Pos 3=Rend
nominal = 10000;
fprintf('\tNominal\t\t\t: %i $\n\n', nominal);
%pf_HML(1, 2) = nominal;
%pf_HML(1, 5) = nominal;

FCU_ask = dataset2cell(FCU_ask);
FCU_bid = dataset2cell(FCU_bid);
DCU_ask = dataset2cell(DCU_ask);
DCU_bid = dataset2cell(DCU_bid);
DR_bid = dataset2cell(DR_bid);
DR_ask = dataset2cell(DR_ask);
DR_mid = dataset2cell(DR_mid);
FX_prop = transpose(dataset2cell(FX_prop));

list_ccy_fx = FCU_ask(1,:);
list_ccy_prop = FX_prop(1,:);
list_ccy_dr = DR_ask(1,:);


%% Initialisation stratégie High Minus Low (HML)
% Classements des devises selon leurs taux de dépots (Mid)
% Pour chaque période de trading (et selon la fréquence choisie
% précédement), les devises sont classés par ordre croissant.
% Seuls les X premieres et dernières devises sont conservées (X = nb_cur_by_pf). 
% Le portefeuille de devises faibles correspond aux X premiers codes
% devises ISO
% Le portefeuille de devises fortes correspond aux X derniers codes devises
% ISO
fprintf('Stratégie HML:\n\tConstitution des portefeuilles...\n');
C = cell(NB_CUR, 2);
C(:,1) = pf_cur_ew_mom;
for j=1:DATA_LEN,
    C(:,2) = ON_rates(j,:);
    D = sortrows(C, 2);
    D(nb_cur_by_pf+1:NB_CUR-nb_cur_by_pf,:) = []; % On ne garde que les n premiers et n derniers taux IB
    pf_cur_hml(j,:) = D(:,1);
    pf_cur_hml_low(j,:) = D(1:nb_cur_by_pf,1);
    pf_cur_hml_high(j,:) = D((nb_cur_by_pf+1):end,1);
end;
clear j ON_rates C D;

%% Boucle principale du programme
% Elle réalise le calcule des payoffs de chaque stratégie étudiée dans le
% cadre de notre projet
fprintf('\nMain program:\n');
pf_cur_ew_mom(my_find(pf_cur_ew_mom, 'USD')) = [];
pf_cur_ew_all = pf_cur_ew_mom;
strategie_EW = zeros(DATA_LEN, 3, length(pf_cur_ew_all));

index_pf_low        = my_find(list_ccy_fx, pf_cur_hml_low(1,:));
index_pf_high       = my_find(list_ccy_fx, pf_cur_hml_high(1,:));
index_dr_low        = my_find(list_ccy_dr, pf_cur_hml_low(1,:));
index_dr_high       = my_find(list_ccy_dr, pf_cur_hml_high(1,:));

low_fxrates_fcu_prev    = cell2mat([FCU_bid(2,index_pf_low) ; FCU_ask(2,index_pf_low)]);
high_fxrates_fcu_prev   = cell2mat([FCU_bid(2,index_pf_high) ; FCU_ask(2,index_pf_high)]);
low_fxrates_dcu_prev    = cell2mat([DCU_bid(2,index_pf_low) ; DCU_ask(2,index_pf_low)]);
high_fxrates_dcu_prev   = cell2mat([DCU_bid(2,index_pf_high) ; DCU_ask(2,index_pf_high)]);
low_dr_prev             = cell2mat([DR_bid(2, index_dr_low) ; DR_ask(2, index_dr_low)]) ./ 100;
high_dr_prev            = cell2mat([DR_bid(2, index_dr_high) ; DR_ask(2, index_dr_high)]) ./ 100;


for k=2:(DATA_LEN),
    %% Constitution des données
    % Récupération pour chaque période de trading des taux en vigueur
    % durant la période: taux de dépot/placement, taux de changes,
    % proprités relatives à chaque devise traitée dans le cadre des
    % stratégies mises en oeuvre (ew = Equally Weighted, low/high = HML)
    index_pf_ew         = my_find(list_ccy_fx, pf_cur_ew_all);
    index_pf_low        = my_find(list_ccy_fx, pf_cur_hml_low(k-1,:));
    index_pf_high       = my_find(list_ccy_fx, pf_cur_hml_high(k-1,:));

    index_prop_ew = my_find(list_ccy_prop, pf_cur_ew_all);
    index_prop_low = my_find(list_ccy_prop, pf_cur_hml_low(k-1,:));
    index_prop_high = my_find(list_ccy_prop, pf_cur_hml_high(k-1,:));

    % Les taux de dépots US sont récupérés séparement pour la mise en
    % oeuvre de la stratégie EW
    index_dr_usd = my_find(list_ccy_dr, 'USD');
    index_dr_ew = my_find(list_ccy_dr, pf_cur_ew_all);
    index_dr_low = my_find(list_ccy_dr, pf_cur_hml_low(k-1,:));
    index_dr_high = my_find(list_ccy_dr, pf_cur_hml_high(k-1,:));

    % Récupération des taux de changes Bid et Ask (2x1)
    % Ligne 1: taux Bid
    % Ligne 2: taux Ask
    % La dénomination DCU (resp. FCU) correspond aux taux de changes
    % Domestic Currency Unit (resp. Foreign Currency Unit) vis-à-vis de la
    % monnaie domestic choisie dans le cadre de notre étude : USD (Dollar
    % US)
    %
    % Ex: 1$ = 0,8567€ est le taux DCU (par rapport au dollar)
    %     1€ = 1,2873$ est le taux FCU (par rapport au dollar)
    %
    ew_fxrates_fcu         = cell2mat([FCU_bid(k,index_pf_ew) ; FCU_ask(k,index_pf_ew)]);
    ew_fxrates_fcu_next    = cell2mat([FCU_bid(k+1,index_pf_ew) ; FCU_ask(k+1,index_pf_ew)]);
    ew_fxrates_dcu         = cell2mat([DCU_bid(k,index_pf_ew) ; DCU_ask(k,index_pf_ew)]);
    ew_fxrates_dcu_next    = cell2mat([DCU_bid(k+1,index_pf_ew) ; DCU_ask(k+1,index_pf_ew)]);
    
    low_fxrates_fcu         = cell2mat([FCU_bid(k,index_pf_low) ; FCU_ask(k,index_pf_low)]);
    low_fxrates_fcu_next    = cell2mat([FCU_bid(k+1,index_pf_low) ; FCU_ask(k+1,index_pf_low)]);
    high_fxrates_fcu        = cell2mat([FCU_bid(k,index_pf_high) ; FCU_ask(k,index_pf_high)]);
    high_fxrates_fcu_next   = cell2mat([FCU_bid(k+1,index_pf_high) ; FCU_ask(k+1,index_pf_high)]);
    low_fxrates_dcu         = cell2mat([DCU_bid(k,index_pf_low) ; DCU_ask(k,index_pf_low)]);
    high_fxrates_dcu        = cell2mat([DCU_bid(k,index_pf_high) ; DCU_ask(k,index_pf_high)]);

    
    % Récupération des taux de dépots/placements Bid et Ask (2x1)
    % Ligne 1: taux Bid
    % Ligne 2: taux Ask
    % La dénomination DR correspond à Deposit Rate. Les cotations
    % récupérées par Bloomberg sont exprimées en pourcentage et doivent
    % être divisées par 100 pour correspondre au bon taux dans une base
    % décimale.
    %
    us_dr                   = cell2mat([DR_bid(k, index_dr_usd) ; DR_ask(k, index_dr_usd)]) ./ 100;
    us_dr_mid               = cell2mat(DR_mid(k, index_dr_usd)) ./ 100;
    ew_dr                   = cell2mat([DR_bid(k, index_dr_ew) ; DR_ask(k, index_dr_ew)]) ./ 100;
    ew_dr_mid               = cell2mat(DR_mid(k, index_dr_ew)) ./ 100;
    low_dr                  = cell2mat([DR_bid(k, index_dr_low) ; DR_ask(k, index_dr_low)]) ./ 100;
    high_dr                 = cell2mat([DR_bid(k, index_dr_high) ; DR_ask(k, index_dr_high)]) ./ 100;   

    
    % Récupération des propriétés relatives à chaque devise:
    % Base annuelle du calcul des taux (ex. 360 ou 365)
    % Base nominal de cotation pour le taux de change (ex. La cotation en dollar du Yen est affichée pour 100 Yens)
    ew_base_yr              = frequency;
    low_base_yr             = frequency;
    high_base_yr            = frequency;
    ew_base_fx              = cell2mat(FX_prop(3, index_prop_ew));
    low_base_fx             = cell2mat(FX_prop(3, index_prop_low));
    high_base_fx            = cell2mat(FX_prop(3, index_prop_high));


    fprintf('%s: \n', datestr(Date(k)));
 
    %% Boucle de trading de la stratégie Equally-Weighted (EW)
    % Le payoff de la période correspond à la consolidation des payoffs de
    % tous les carry trades mis en oeuvre un à un. La monnaie domestique étant le
    % Dollar US, les carry trade mis en oeuvre respecte la configuration
    % suivante : la devise faible est l'USD et la devise forte est l'une
    % des autres devises du pool de devises global.
    % Etant donnée la présence de l'USD dans le pool global de devises,
    % nous ne considérons pas le carry trade USD vs USD, qui n'a aucun sens
    % pour nous dans le cadre de notre étude.
    nb_cur_ew_all = length(pf_cur_ew_all);
    item_EW = zeros(nb_cur_ew_all, 1);
    item_EW_inv = zeros(nb_cur_ew_all, 1);
    fprintf('Stratégie EW:\n');
    for i=1:nb_cur_ew_all,
        % Le différentiel de taux entre les devises permet de déterminer
        % quelle est la position à prendre sur le Dollar (short ou
        % long).
        % En théorie, les formules de parité des taux de change croisés
        % permet d'établir une égalité entre DCU_bid = 1 / FCU_ask. Mais en
        % réalité cette égalité n'est pas vérifié sur le marché, d'où
        % l'ajustement de la formule de payoff en fonction du sens du carry
        % trade.
        if (us_dr_mid <= ew_dr_mid(1, i))
            % item_EW_inv permet de stocker ce que serait le payoff du
            % carry trade inverse. Cela nous est utile dans le cadre de la
            % couverture de la stratégie EW par Momentum: le spread bid-ask
            % des taux de dépôts/placements étant non nul.
            item_EW(i) = nominal * (((ew_fxrates_dcu(1,i) * (1 + ((ew_dr(1,i) / ew_base_yr)))) * ew_fxrates_fcu_next(1,i)) - (1 + (us_dr(2,1) / ew_base_yr)));
            item_EW_inv(i) = nominal * ((1 + (us_dr(1,1) / ew_base_yr)) - ((ew_fxrates_fcu_next(1, i)/ew_fxrates_fcu(1, i)) * (1 + ((ew_dr(2,i) / ew_base_yr)))));
            fprintf('\tCarry trade: USD - %s\t=\t%6.4f $\n', pf_cur_ew_all{i}, item_EW(i));
        else
            item_EW(i) = nominal * ((1 + (us_dr(1,1) / ew_base_yr)) - ((ew_fxrates_fcu_next(1, i)/ew_fxrates_fcu(1, i)) * (1 + ((ew_dr(2,i) / ew_base_yr)))));
            item_EW_inv(i) = nominal * (((ew_fxrates_dcu(1,i) * (1 + ((ew_dr(1,i) / ew_base_yr)))) * ew_fxrates_fcu_next(1,i)) - (1 + (us_dr(2,1) / ew_base_yr)));
            fprintf('\tCarry trade: %s - USD\t=\t%6.4f $\n', pf_cur_ew_all{i}, item_EW(i));
        end
        strategie_EW(k, 1, i) = item_EW(i);
        strategie_EW(k, 2, i) = item_EW_inv(i);
    end
    total_EW = sum(item_EW);
    
    % Composition du tableau de résulat de la stratégie EW
    % 1ère colonne: consolidation des payoffs de carry trade individuels
    % 2ème colonne: somme cumulée des payoffs consolidés de la stratégie EW
    % 3ème colonne: taux de rendements de la période
    pf_EW(k, 1) = total_EW;
    pf_EW(k, 2) = pf_EW(k-1, 2) + pf_EW(k, 1);
    pf_EW(k, 3) = pf_EW(k, 1) / pf_EW(k-1, 2);
    
    %% Boucle de trading de la stratégie HML
    % La boucle de trading de la stratégie HML est scindée en 2 parties:
    %     1) Calcul du coûts d'emprunts dans la devise faible
    %     2) Calcul des intérêts perçus dans la devise forte
    % Le calcul des intérêts à payer et percus se faisant dans les devises
    % locales, une conversion vers la monnaie domestique (ici l'USD) est
    % de rigueur pour identifier le rendement du trade sur la période
    fprintf('Stratégie HML:\n');
    total_borrowing_low_cost_usd = 0;
    total_borrowing_low_cost_usd_prev = 0;
    total_lending_high_usd = 0;
    total_lending_high_usd_prev = 0;
    period_cur_hml = pf_cur_hml(k-1, :);
    
    
    % Récupération des données financières de l'instant (t-1) des devises 
    % sélectionnées à l'instant t. Ces données sont utiles à calculer le
    % payoff de la période précédente afin d'en déterminer son signe et de
    % se couvrir de façon adéquante avec un HML Momentum
    if (k > 2)
        low_fxrates_fcu_prev    = cell2mat([FCU_bid(k-1,index_pf_low) ; FCU_ask(k-1,index_pf_low)]);
        high_fxrates_fcu_prev   = cell2mat([FCU_bid(k-1,index_pf_high) ; FCU_ask(k-1,index_pf_high)]);
        low_fxrates_dcu_prev    = cell2mat([DCU_bid(k-1,index_pf_low) ; DCU_ask(k-1,index_pf_low)]);
        high_fxrates_dcu_prev   = cell2mat([DCU_bid(k-1,index_pf_high) ; DCU_ask(k-1,index_pf_high)]);
        low_dr_prev             = cell2mat([DR_bid(k-1, index_dr_low) ; DR_ask(k-1, index_dr_low)]) ./ 100;
        high_dr_prev            = cell2mat([DR_bid(k-1, index_dr_high) ; DR_ask(k-1, index_dr_high)]) ./ 100;   
    end
    
    fprintf('\tPortefeuille S1:\t');
    for word = pf_cur_hml_low(k-1, :),
        fprintf('%s\t', word{:});
    end
    fprintf('\n');
    for i=1:nb_cur_by_pf,
        current_cur = period_cur_hml(i);
        % Le nominal à emprunter sur chaque devise faible est déterminé en
        % fontion du nominal choisi initialement. Le nominal total à 
        % investir est réparti equitablement sur chaque carry trade
        % individuel(nominal / nb_cur_by_pf) $. De fait, si un portefeuille
        % de devise faible est consititué de 5 devises, alors le nominal à
        % considéré sur chaque emprunt est de l'ordre de 2500$. Sauf si
        % l'USD fait lui même partie des devises faibles. Dans ce cas, il
        % n'y a aucun intérêt à l'emprunter car nous l'avons déjà en
        % possession.
        % Cette part de nominal par devise est à convertir ensuite en 
        % monnaie foreign afin de calculer les coûts d'emprunts.
        % Le processus financier mis en place derrière est :
        %   1) Calcul du montant en dollar à emprunter
        %   2) Conversion de la somme à emprunter en devise foreign
        %   3) Calcul du coût d'emprunt (taux de dépôts Ask de la devise foreign)
        %   4) Conversion du coût de l'emprunt en USD
        
        fprintf('\t\t%s: ', current_cur{:});
        nb_cur_pf_low = nb_cur_by_pf;
        % Vérification si le dollar fait partie du portefeuille de devise
        % faible. Si tel est le cas, alors nb_cur_pf_low permettra de
        % réajuster au plus juste le montant du nominal à emprunter
        if (~isempty(find(ismember(period_cur_hml(1:nb_cur_by_pf), 'USD'), 1)))
            nb_cur_pf_low = nb_cur_by_pf - 1;
        end
        
        % Si le portefeuille n'est consitué que d'une seule devise et qu'il
        % s'agit du dollar US, alors le coût d'emprunt est de 0. 
        if (nb_cur_pf_low == 0)
            borrowing_low_cost_usd = 0;
            fprintf('\t0 $');
        else
            prev_borrowing_low_usd = 0;
            prev_borrowing_low_foreign = 0;
            prev_borrowing_low_foreign_eop = 0;
            prev_borrowing_low_usd_eop = 0;    
            prev_borrowing_low_cost_usd = 0;
            
            if (strcmp(current_cur, 'USD'))
                % Si le Dollar US est présent dans les devises faibles
                % alors sont cout d'emprunt est de 0. Nul ne sert de
                % l'emprunter si ma devise comptable est de l'USD.
                % L'économie est donc le spread Bid-Ask.
                borrowing_low_usd = 0;
                borrowing_low_foreign = 0;
                borrowing_low_foreign_eop = 0; % EOP = End of Period
                borrowing_low_usd_eop = 0;    
                borrowing_low_cost_usd = 0;
            else
                % Calcul du coût d'emprunt de la currency selectionnée en t
                % à l'instant t
                borrowing_low_usd = (nominal / nb_cur_pf_low);
                borrowing_low_foreign = borrowing_low_usd * low_fxrates_dcu(1,i);
                borrowing_low_foreign_eop = borrowing_low_foreign * (1 + (low_dr(2,i) / low_base_yr)); % EOP = End of Period
                borrowing_low_usd_eop = low_fxrates_fcu_next(1,i) * borrowing_low_foreign_eop; % EOP = End of Period
                borrowing_low_cost_usd = borrowing_low_usd_eop - borrowing_low_usd;
                
                % Calcul du coût d'emprunt de la currency selectionnée en t
                % à l'instant (t-1)
                if (k > 2),
                    prev_borrowing_low_usd = (nominal / nb_cur_pf_low);
                    prev_borrowing_low_foreign = prev_borrowing_low_usd * low_fxrates_dcu_prev(1,i);
                    prev_borrowing_low_foreign_eop = prev_borrowing_low_foreign * (1 + (low_dr_prev(2,i) / low_base_yr)); % EOP = End of Period
                    prev_borrowing_low_usd_eop = low_fxrates_fcu(1,i) * prev_borrowing_low_foreign_eop; % EOP = End of Period
                    prev_borrowing_low_cost_usd = prev_borrowing_low_usd_eop - prev_borrowing_low_usd;
                end
            end
            fprintf('\t%6.4f $ ~ %6.4f (%s) ---> %6.4f (%s) ~ %6.4f $ (%6.4f $)\n', borrowing_low_usd, borrowing_low_foreign, current_cur{:}, borrowing_low_foreign_eop, current_cur{:}, borrowing_low_usd_eop, borrowing_low_cost_usd);
        end
        total_borrowing_low_cost_usd = total_borrowing_low_cost_usd + borrowing_low_cost_usd;
        total_borrowing_low_cost_usd_prev = total_borrowing_low_cost_usd_prev + prev_borrowing_low_cost_usd;
    end
    fprintf('\t\t\t ==== TOTAL: %6.4f $ (Previously: %6.4f $)====\n', total_borrowing_low_cost_usd, total_borrowing_low_cost_usd_prev); 
    
    
    fprintf('\n\tPortefeuille S5:\t');
    for word = pf_cur_hml_high(k-1,:),
        fprintf('%s\t', word{:});
    end
    fprintf('\n');
    for i=1:nb_cur_by_pf,
        % Par soucis de parallélisme, le nominal total emprunté doit
        % correspondre au nominal placé. De fait, si un portefeuille
        % de devise forte est consititué de 5 devises, alors le nominal à
        % considéré sur chaque placement est de l'ordre de 2500$.
        % Le processus financier mis en place derrière est :
        %   1) Calcul du montant en dollar à placer = montant de l'emprunt
        %   2) Conversion de la somme à placer en devise foreign
        %   3) Calcul des intérêts perçus (taux de dépôts Bid de la devise foreign)
        %   4) Conversion des intérêts perçus de l'emprunt en USD
        lending_high_usd = (nominal / nb_cur_by_pf);
        lending_high_usd_prev = 0;
        current_cur = period_cur_hml(i + nb_cur_by_pf);
        fprintf('\t\t%s: ', current_cur{:});
        
        % Si le portefeuille de devise forte est constitué du dollar US,
        % alors nous pouvons économiser le spread bid-ask de conversion
        % applicable pour les autres devises. Pour autant, nosu profitons
        % du taux de dépôt applicable aux US
        if (strcmp(current_cur, 'USD'))
            
            % Calcul des intérêts perçus de l'USD à la période t
            lending_high_foreign = lending_high_usd;
            lending_high_foreign_eop = lending_high_foreign * (1 + ((high_dr(1,i) ./ high_base_yr))); % EOP = End of Period
            lending_high_usd_eop = lending_high_foreign_eop; % EOP = End of Period
            lending_high_usd_eop_prev = 0;
            
            % Calcul des intérêts perçus de l'USD à la période (t-1)
            if (k > 2)
                lending_high_usd_prev = lending_high_usd;
                lending_high_foreign_prev = lending_high_usd;
                lending_high_foreign_eop_prev = lending_high_foreign_prev * (1 + ((high_dr_prev(1,i) ./ high_base_yr))); % EOP = End of Period
                lending_high_usd_eop_prev = lending_high_foreign_eop_prev; % EOP = End of Period
            end
        else
            % Calcul des intérêts perçus de la currency selectionnée en t
            % à l'instant t
            lending_high_foreign = lending_high_usd * high_fxrates_dcu(1,i);
            lending_high_foreign_eop = lending_high_foreign * (1 + ((high_dr(1,i) ./ high_base_yr))); % EOP = End of Period
            lending_high_usd_eop = high_fxrates_fcu_next(1,i) * lending_high_foreign_eop; % EOP = End of Period

            % Calcul des intérêts perçus de la currency selectionnée en t
            % à l'instant (t-1)
            if (k > 2)
                lending_high_foreign_prev = lending_high_usd_prev * high_fxrates_dcu_prev(1,i);
                lending_high_foreign_eop_prev = lending_high_foreign_prev * (1 + ((high_dr_prev(1,i) ./ high_base_yr))); % EOP = End of Period
                lending_high_usd_eop_prev = high_fxrates_fcu(1,i) * lending_high_foreign_eop_prev; % EOP = End of Period
            end
            
        end
        lending_high_interest_usd = lending_high_usd_eop - lending_high_usd;
        lending_high_interest_usd_prev = lending_high_usd_eop_prev - lending_high_usd_prev;
        fprintf('\t%6.4f $ ~ %6.4f (%s) ---> %6.4f (%s) ~ %6.4f $ (%6.4f $)\n', lending_high_usd, lending_high_foreign, current_cur{:}, lending_high_foreign_eop, current_cur{:}, lending_high_usd_eop, lending_high_interest_usd);
        total_lending_high_usd = total_lending_high_usd + lending_high_interest_usd;
        
        if (k <= 2)
            % Initialisation des payoff pour la période t=-1
            total_lending_high_usd_prev = 0;
        else
            total_lending_high_usd_prev = total_lending_high_usd_prev + lending_high_interest_usd_prev;
        end
    end
    fprintf('\t\t\t ==== TOTAL: %6.4f $ (Previously: %6.4f $) ====\n', total_lending_high_usd, total_lending_high_usd_prev);     
    
    % Composition du tableau de résulat de la stratégie HML
    % 1ère colonne: Calcul du payoff du carry trade S1 vs S5 en t à
    %               l'instant t
    %               (intérêts perçus suite au placement sur S5 - coût 
    %               d'emprunt de S1)
    % 2ème colonne: somme cumulée des payoffs de la stratégie HML
    % 3ème colonne: taux de rendements de la période 
    % 4èùe colonne: Calcul du payoff du carry trade S1 vs S5 en t à
    %               l'instant t-1
    %               (intérêts perçus suite au placement sur S5 - coût
    %               d'emprunt de S1) : utile pour la stratégie HML Momentum
    pf_HML(k, 1) = total_lending_high_usd - total_borrowing_low_cost_usd;
    pf_HML(k, 2) = pf_HML(k-1, 2) + pf_HML(k, 1);
    pf_HML(k, 3) = pf_HML(k, 1) / pf_HML(k-1, 2);
    pf_HML(k, 4) = total_lending_high_usd_prev - total_borrowing_low_cost_usd_prev;
end


%% Stratégie de couverture Momentum High Minus Low (HML)
% Le tablea de résulat de la stratégie HML est complétée de 2 nouvelles
% colonnes pour les résultats du Momentum
% 5ème colonne: calcul du payoff de la stratégie HML Momentum
% 6ème colonne: somme cumulée des payoffs consolidés de la stratégie HML
%               Momentum
line = length(pf_HML);
pf_HML(1, 2) = 0;
pf_HML(1, 5) = 0;
for i=2:line,
    Zt_prev = pf_HML(i, 4)-pf_HML(i-1,4);
    Zt = pf_HML(i, 1);
    pf_HML(i, 5) = sign(Zt_prev) * Zt;
    pf_HML(i, 6) = pf_HML(i-1, 6) + pf_HML(i, 5);
end

%% Stratégie de couverture Momentum Equally-Weighted
% Le tableau de résultat de la stratégie EW est complétée de 2 nouvelles
% colonnes pour les résultats du Momentum
% 1ère colonne: consolidation des payoffs de carry trade individuels
% 2ème colonne: somme cumulée des payoffs consolidés de la stratégie EW Mom
pf_EW(1, 5) = 0;
[line, ~, nb_cur] = size(strategie_EW);
for i=2:line,
    total_EW_mom = 0;
    
    % Parcours de chaque devise contre l'USD
    % Zt_prev correspond au payoff du carry trade effectué en t-1
    % Zt correspond au payoff du carry trade effectué en t
    for j=1:nb_cur,
        Zt_prev = strategie_EW((i-1), 1, j);
        Zt = strategie_EW(i, 1, j);
        
        % Vérification des cas de figures correspondant à un changement de
        % signe du payoff actuel par prise en compte du signe du payoff
        % précédent. Si tel est le cas, on considère le carry trade inverse
        % que l'on a pris le soin de calculer dans la 2ème colonne de
        % strategie_EW
        if (((sign(Zt_prev) < 0) && (sign(Zt) < 0)) || ((sign(Zt_prev) < 0) && (sign(Zt) >= 0)))
            strategie_EW(i, 3, j) = strategie_EW(i, 2, j);
        else
            strategie_EW(i, 3, j) = sign(Zt_prev) * Zt;
        end
        total_EW_mom = total_EW_mom + strategie_EW(i, 3, j);
    end
    pf_EW(i, 4) = total_EW_mom;
    pf_EW(i, 5) = pf_EW((i-1), 5) + total_EW_mom;
end

%% Stratégie de couverture Momentum Equally-Weighted en fonction des n derniers payoffs
% Le tableau de résultat de la stratégie EW est complétée de 3 nouvelles
% colonnes pour les résultats du Momentum EW en fonction des n derniers
% payoffs.
% La stratégie consiste à se couvrir uniquement si le cumul des n derniers
% payoffs est inférieur à -1 écart type des n dernières observations.
pf_EW(1, 8) = 0;
[line, col, nb_cur] = size(strategie_EW);
deepness = 3;
for i=(deepness+1):line,
    total_EW_mom = 0;
    for j=1:11,
        cum_n_derniers_PnL = sum(strategie_EW((i-deepness):i, 1, j));
        ecart_type = std(strategie_EW((i-deepness):i, 1, j));
        Zt_prev = strategie_EW((i-1), 1, j);
        Zt = strategie_EW(i, 1, j);
        if (cum_n_derniers_PnL < -(ecart_type))
            strategie_EW(i, 3, j) = strategie_EW(i, 2, j);
        else
             strategie_EW(i, 3, j) = Zt;
        end
        total_EW_mom = total_EW_mom + strategie_EW(i, 3, j);
    end
    pf_EW(i, 7) = total_EW_mom;
    pf_EW(i, 8) = pf_EW((i-1), 5) + total_EW_mom;
end

%% Calcul du Max Drowdown EW
% M: Maximum atteint de la somme cumulée des P&L à l'instant t
% DD: Drowdown courant à l'instant t
% MDD: Maximum Drowdown à l'instant t (Max(DD))
% 3 colonnes pour chaque variable: calcul des 3 MDD pour la stratégie EW,
% EW couverture Momentum et EW couverture Momentum Std
line = length(pf_EW);
M_EW = zeros(1, 3);
DD_EW = zeros(1, 3);
MDD_EW = zeros(1, 3);
mdd_date_EW = zeros(1, 3);
position_mdd_EW = zeros(1, 3);
mdd_m_EW = zeros(1, 3);
for i=1:line,
    EW_Mom = pf_EW(i,2) + pf_EW(i,5);
    EW_Mom_std = pf_EW(i,2) + pf_EW(i,8);
    M_EW(1,1) = max(M_EW(1,1), pf_EW(i,2));
    M_EW(1,2) = max(M_EW(1,2), EW_Mom);
    M_EW(1,3) = max(M_EW(1,3), EW_Mom_std);
    DD_EW(1,1) = M_EW(1,1) - pf_EW(i,2);
    DD_EW(1,2) = M_EW(1,2) - EW_Mom;
    DD_EW(1,3) = M_EW(1,3) - EW_Mom_std;
    if (MDD_EW(1,1) <= DD_EW(1,1))
        mdd_m_EW(1,1) = M_EW(1,1);
        mdd_date_EW(1,1) = i;
        position_mdd_EW(1,1) = pf_EW(i,2);
        MDD_EW(1,1) = DD_EW(1,1);
    end
    if (MDD_EW(1,2) <= DD_EW(1,2))
        mdd_m_EW(1,2) = M_EW(1,2);
        mdd_date_EW(1,2) = i;
        position_mdd_EW(1,2) = EW_Mom;
        MDD_EW(1,2) = DD_EW(1,2);
    end
    if (MDD_EW(1,3) <= DD_EW(1,3))
        mdd_m_EW(1,3) = M_EW(1,3);
        mdd_date_EW(1,3) = i;
        position_mdd_EW(1,3) = EW_Mom_std;
        MDD_EW(1,3) = DD_EW(1,3);
    end
end



%% Calcul du Max Drowdown HML
% M: Maximum atteint de la somme cumulée des P&L à l'instant t
% DD: Drowdown courant à l'instant t
% MDD: Maximum Drowdown à l'instant t (Max(DD))
% 2 colonnes pour chaque variable: calcul des 2 MDD pour la stratégie HML,
% HML couverture Momentum
line = length(pf_HML);
M_HML = zeros(1, 2);
DD_HML = zeros(1, 2);
MDD_HML = zeros(1, 2);
mdd_date_HML = zeros(1, 2);
position_mdd_HML = zeros(1, 2);
mdd_m_HML = zeros(1, 2);
for i=1:line,
    HML_Mom = pf_HML(i,2) + pf_HML(i,6);
    M_HML(1,1) = max(M_HML(1,1), pf_HML(i,2));
    M_HML(1,2) = max(M_HML(1,2), HML_Mom);
   
    DD_HML(1,1) = M_HML(1,1) - pf_HML(i,2);
    DD_HML(1,2) = M_HML(1,2) - HML_Mom;

    if (MDD_HML(1,1) <= DD_HML(1,1))
        mdd_m_HML(1,1) = M_HML(1,1);
        mdd_date_HML(1,1) = i;
        position_mdd_HML(1,1) = pf_HML(i,2);
        MDD_HML(1,1) = DD_HML(1,1);
    end
    if (MDD_HML(1,2) <= DD_HML(1,2))
        mdd_m_HML(1,2) = M_HML(1,2);
        mdd_date_HML(1,2) = i;
        position_mdd_HML(1,2) = HML_Mom;
        MDD_HML(1,2) = DD_HML(1,2);
    end
end

%% Résultats: Traçage des graphiques 
fprintf('\n=============================== RESULTS =====================================\n');


figure;
plot(pf_dates, pf_EW(:,2), pf_dates, pf_EW(:,5), pf_dates, pf_EW(:,8), pf_dates, pf_EW(:,2)+pf_EW(:,5), pf_dates, pf_EW(:,2)+pf_EW(:,8));
legend('EW','EW Momentum', 'EW Momentum STD', 'EW couvert Mom', 'EW couvert Mom STD')
datetick('x','keepticks','keeplimits')
title('PnL de la Stratégie Equally-Weighted');

fprintf('\tMAXIMUM DROWDOWN EW:\n');
fprintf('\t\t- EW\t\t\t\t\t\t: %6.2f %% (atteint le %s)\n', (position_mdd_EW(1,1) - mdd_m_EW(1,1))/mdd_m_EW(1,1)*100, datestr(pf_dates(mdd_date_EW(1,1)), 'dd-mmm-yyyy'));
fprintf('\t\t- EW couverture Momentum\t: %6.2f %% (atteint le %s)\n', (position_mdd_EW(1,2) - mdd_m_EW(1,2))/mdd_m_EW(1,2)*100, datestr(pf_dates(mdd_date_EW(1,2)), 'dd-mmm-yyyy'));
fprintf('\t\t- EW couverture Momentum Std: %6.2f %% (atteint le %s)\n', (position_mdd_EW(1,3) - mdd_m_EW(1,3))/mdd_m_EW(1,3)*100, datestr(pf_dates(mdd_date_EW(1,3)), 'dd-mmm-yyyy'));

figure;
plot(pf_dates, pf_HML(:,2), pf_dates, pf_HML(:,6), pf_dates,  pf_HML(:,6) + pf_HML(:,2));
legend('HML','HML Momentum', 'HML couvert Mom');
datetick('x','keepticks','keeplimits');
title('PnL de la Stratégie HML');

fprintf('\tMAXIMUM DROWDOWN HML:\n');
fprintf('\t\t- HML\t\t\t\t\t\t: %6.2f %% (atteint le %s)\n', (position_mdd_HML(1,1) - mdd_m_HML(1,1))/mdd_m_HML(1,1)*100, datestr(pf_dates(mdd_date_HML(1,1)), 'dd-mmm-yyyy'));
fprintf('\t\t- HML couverture Momentum\t: %6.2f %% (atteint le %s)\n', (position_mdd_HML(1,2) - mdd_m_HML(1,2))/mdd_m_HML(1,2)*100, datestr(pf_dates(mdd_date_HML(1,2)), 'dd-mmm-yyyy'));

%back testing
Variation_Couvert_Momentum= pf_HML(1:line,2) - [0; pf_HML(1:line-1,2)]+pf_HML(1:line,6) - [0; pf_HML(1:line-1,6)]
Variation_Non_Couvert= pf_HML(1:line,2) - [0; pf_HML(1:line-1,2)]
C=zeros(line-1,1)
delta_error=0.001
for i=3:line
        C(i)=Variation_Couvert_Momentum(i)/Variation_Non_Couvert(i)       
        if (abs(sign(sign(delta_error - C(i)) + sign(-delta_error - C(i)))))
            if (abs(sign(sign(2+delta_error - C(i)) + sign(2-delta_error - C(i)))))
            error('HML is not implemented correctly, as Variation of couvert momentum is not either 0 or the double of Variation non couvert')
            end
        end
end
        