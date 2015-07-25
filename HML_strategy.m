%% Initialisation du programme de trading
% Chargement des donn�es selon la fr�quence frequency
% Choix du nombre de devises par portefeuille pour la strat�gie HML
% Choix de la mise de d�part � investir
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


%% Initialisation strat�gie High Minus Low (HML)
% Classements des devises selon leurs taux de d�pots (Mid)
% Pour chaque p�riode de trading (et selon la fr�quence choisie
% pr�c�dement), les devises sont class�s par ordre croissant.
% Seuls les X premieres et derni�res devises sont conserv�es (X = nb_cur_by_pf). 
% Le portefeuille de devises faibles correspond aux X premiers codes
% devises ISO
% Le portefeuille de devises fortes correspond aux X derniers codes devises
% ISO
fprintf('Strat�gie HML:\n\tConstitution des portefeuilles...\n');
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
% Elle r�alise le calcule des payoffs de chaque strat�gie �tudi�e dans le
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
    %% Constitution des donn�es
    % R�cup�ration pour chaque p�riode de trading des taux en vigueur
    % durant la p�riode: taux de d�pot/placement, taux de changes,
    % proprit�s relatives � chaque devise trait�e dans le cadre des
    % strat�gies mises en oeuvre (ew = Equally Weighted, low/high = HML)
    index_pf_ew         = my_find(list_ccy_fx, pf_cur_ew_all);
    index_pf_low        = my_find(list_ccy_fx, pf_cur_hml_low(k-1,:));
    index_pf_high       = my_find(list_ccy_fx, pf_cur_hml_high(k-1,:));

    index_prop_ew = my_find(list_ccy_prop, pf_cur_ew_all);
    index_prop_low = my_find(list_ccy_prop, pf_cur_hml_low(k-1,:));
    index_prop_high = my_find(list_ccy_prop, pf_cur_hml_high(k-1,:));

    % Les taux de d�pots US sont r�cup�r�s s�parement pour la mise en
    % oeuvre de la strat�gie EW
    index_dr_usd = my_find(list_ccy_dr, 'USD');
    index_dr_ew = my_find(list_ccy_dr, pf_cur_ew_all);
    index_dr_low = my_find(list_ccy_dr, pf_cur_hml_low(k-1,:));
    index_dr_high = my_find(list_ccy_dr, pf_cur_hml_high(k-1,:));

    % R�cup�ration des taux de changes Bid et Ask (2x1)
    % Ligne 1: taux Bid
    % Ligne 2: taux Ask
    % La d�nomination DCU (resp. FCU) correspond aux taux de changes
    % Domestic Currency Unit (resp. Foreign Currency Unit) vis-�-vis de la
    % monnaie domestic choisie dans le cadre de notre �tude : USD (Dollar
    % US)
    %
    % Ex: 1$ = 0,8567� est le taux DCU (par rapport au dollar)
    %     1� = 1,2873$ est le taux FCU (par rapport au dollar)
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

    
    % R�cup�ration des taux de d�pots/placements Bid et Ask (2x1)
    % Ligne 1: taux Bid
    % Ligne 2: taux Ask
    % La d�nomination DR correspond � Deposit Rate. Les cotations
    % r�cup�r�es par Bloomberg sont exprim�es en pourcentage et doivent
    % �tre divis�es par 100 pour correspondre au bon taux dans une base
    % d�cimale.
    %
    us_dr                   = cell2mat([DR_bid(k, index_dr_usd) ; DR_ask(k, index_dr_usd)]) ./ 100;
    us_dr_mid               = cell2mat(DR_mid(k, index_dr_usd)) ./ 100;
    ew_dr                   = cell2mat([DR_bid(k, index_dr_ew) ; DR_ask(k, index_dr_ew)]) ./ 100;
    ew_dr_mid               = cell2mat(DR_mid(k, index_dr_ew)) ./ 100;
    low_dr                  = cell2mat([DR_bid(k, index_dr_low) ; DR_ask(k, index_dr_low)]) ./ 100;
    high_dr                 = cell2mat([DR_bid(k, index_dr_high) ; DR_ask(k, index_dr_high)]) ./ 100;   

    
    % R�cup�ration des propri�t�s relatives � chaque devise:
    % Base annuelle du calcul des taux (ex. 360 ou 365)
    % Base nominal de cotation pour le taux de change (ex. La cotation en dollar du Yen est affich�e pour 100 Yens)
    ew_base_yr              = frequency;
    low_base_yr             = frequency;
    high_base_yr            = frequency;
    ew_base_fx              = cell2mat(FX_prop(3, index_prop_ew));
    low_base_fx             = cell2mat(FX_prop(3, index_prop_low));
    high_base_fx            = cell2mat(FX_prop(3, index_prop_high));


    fprintf('%s: \n', datestr(Date(k)));
 
    %% Boucle de trading de la strat�gie Equally-Weighted (EW)
    % Le payoff de la p�riode correspond � la consolidation des payoffs de
    % tous les carry trades mis en oeuvre un � un. La monnaie domestique �tant le
    % Dollar US, les carry trade mis en oeuvre respecte la configuration
    % suivante : la devise faible est l'USD et la devise forte est l'une
    % des autres devises du pool de devises global.
    % Etant donn�e la pr�sence de l'USD dans le pool global de devises,
    % nous ne consid�rons pas le carry trade USD vs USD, qui n'a aucun sens
    % pour nous dans le cadre de notre �tude.
    nb_cur_ew_all = length(pf_cur_ew_all);
    item_EW = zeros(nb_cur_ew_all, 1);
    item_EW_inv = zeros(nb_cur_ew_all, 1);
    fprintf('Strat�gie EW:\n');
    for i=1:nb_cur_ew_all,
        % Le diff�rentiel de taux entre les devises permet de d�terminer
        % quelle est la position � prendre sur le Dollar (short ou
        % long).
        % En th�orie, les formules de parit� des taux de change crois�s
        % permet d'�tablir une �galit� entre DCU_bid = 1 / FCU_ask. Mais en
        % r�alit� cette �galit� n'est pas v�rifi� sur le march�, d'o�
        % l'ajustement de la formule de payoff en fonction du sens du carry
        % trade.
        if (us_dr_mid <= ew_dr_mid(1, i))
            % item_EW_inv permet de stocker ce que serait le payoff du
            % carry trade inverse. Cela nous est utile dans le cadre de la
            % couverture de la strat�gie EW par Momentum: le spread bid-ask
            % des taux de d�p�ts/placements �tant non nul.
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
    
    % Composition du tableau de r�sulat de la strat�gie EW
    % 1�re colonne: consolidation des payoffs de carry trade individuels
    % 2�me colonne: somme cumul�e des payoffs consolid�s de la strat�gie EW
    % 3�me colonne: taux de rendements de la p�riode
    pf_EW(k, 1) = total_EW;
    pf_EW(k, 2) = pf_EW(k-1, 2) + pf_EW(k, 1);
    pf_EW(k, 3) = pf_EW(k, 1) / pf_EW(k-1, 2);
    
    %% Boucle de trading de la strat�gie HML
    % La boucle de trading de la strat�gie HML est scind�e en 2 parties:
    %     1) Calcul du co�ts d'emprunts dans la devise faible
    %     2) Calcul des int�r�ts per�us dans la devise forte
    % Le calcul des int�r�ts � payer et percus se faisant dans les devises
    % locales, une conversion vers la monnaie domestique (ici l'USD) est
    % de rigueur pour identifier le rendement du trade sur la p�riode
    fprintf('Strat�gie HML:\n');
    total_borrowing_low_cost_usd = 0;
    total_borrowing_low_cost_usd_prev = 0;
    total_lending_high_usd = 0;
    total_lending_high_usd_prev = 0;
    period_cur_hml = pf_cur_hml(k-1, :);
    
    
    % R�cup�ration des donn�es financi�res de l'instant (t-1) des devises 
    % s�lectionn�es � l'instant t. Ces donn�es sont utiles � calculer le
    % payoff de la p�riode pr�c�dente afin d'en d�terminer son signe et de
    % se couvrir de fa�on ad�quante avec un HML Momentum
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
        % Le nominal � emprunter sur chaque devise faible est d�termin� en
        % fontion du nominal choisi initialement. Le nominal total � 
        % investir est r�parti equitablement sur chaque carry trade
        % individuel(nominal / nb_cur_by_pf) $. De fait, si un portefeuille
        % de devise faible est consititu� de 5 devises, alors le nominal �
        % consid�r� sur chaque emprunt est de l'ordre de 2500$. Sauf si
        % l'USD fait lui m�me partie des devises faibles. Dans ce cas, il
        % n'y a aucun int�r�t � l'emprunter car nous l'avons d�j� en
        % possession.
        % Cette part de nominal par devise est � convertir ensuite en 
        % monnaie foreign afin de calculer les co�ts d'emprunts.
        % Le processus financier mis en place derri�re est :
        %   1) Calcul du montant en dollar � emprunter
        %   2) Conversion de la somme � emprunter en devise foreign
        %   3) Calcul du co�t d'emprunt (taux de d�p�ts Ask de la devise foreign)
        %   4) Conversion du co�t de l'emprunt en USD
        
        fprintf('\t\t%s: ', current_cur{:});
        nb_cur_pf_low = nb_cur_by_pf;
        % V�rification si le dollar fait partie du portefeuille de devise
        % faible. Si tel est le cas, alors nb_cur_pf_low permettra de
        % r�ajuster au plus juste le montant du nominal � emprunter
        if (~isempty(find(ismember(period_cur_hml(1:nb_cur_by_pf), 'USD'), 1)))
            nb_cur_pf_low = nb_cur_by_pf - 1;
        end
        
        % Si le portefeuille n'est consitu� que d'une seule devise et qu'il
        % s'agit du dollar US, alors le co�t d'emprunt est de 0. 
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
                % Si le Dollar US est pr�sent dans les devises faibles
                % alors sont cout d'emprunt est de 0. Nul ne sert de
                % l'emprunter si ma devise comptable est de l'USD.
                % L'�conomie est donc le spread Bid-Ask.
                borrowing_low_usd = 0;
                borrowing_low_foreign = 0;
                borrowing_low_foreign_eop = 0; % EOP = End of Period
                borrowing_low_usd_eop = 0;    
                borrowing_low_cost_usd = 0;
            else
                % Calcul du co�t d'emprunt de la currency selectionn�e en t
                % � l'instant t
                borrowing_low_usd = (nominal / nb_cur_pf_low);
                borrowing_low_foreign = borrowing_low_usd * low_fxrates_dcu(1,i);
                borrowing_low_foreign_eop = borrowing_low_foreign * (1 + (low_dr(2,i) / low_base_yr)); % EOP = End of Period
                borrowing_low_usd_eop = low_fxrates_fcu_next(1,i) * borrowing_low_foreign_eop; % EOP = End of Period
                borrowing_low_cost_usd = borrowing_low_usd_eop - borrowing_low_usd;
                
                % Calcul du co�t d'emprunt de la currency selectionn�e en t
                % � l'instant (t-1)
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
        % Par soucis de parall�lisme, le nominal total emprunt� doit
        % correspondre au nominal plac�. De fait, si un portefeuille
        % de devise forte est consititu� de 5 devises, alors le nominal �
        % consid�r� sur chaque placement est de l'ordre de 2500$.
        % Le processus financier mis en place derri�re est :
        %   1) Calcul du montant en dollar � placer = montant de l'emprunt
        %   2) Conversion de la somme � placer en devise foreign
        %   3) Calcul des int�r�ts per�us (taux de d�p�ts Bid de la devise foreign)
        %   4) Conversion des int�r�ts per�us de l'emprunt en USD
        lending_high_usd = (nominal / nb_cur_by_pf);
        lending_high_usd_prev = 0;
        current_cur = period_cur_hml(i + nb_cur_by_pf);
        fprintf('\t\t%s: ', current_cur{:});
        
        % Si le portefeuille de devise forte est constitu� du dollar US,
        % alors nous pouvons �conomiser le spread bid-ask de conversion
        % applicable pour les autres devises. Pour autant, nosu profitons
        % du taux de d�p�t applicable aux US
        if (strcmp(current_cur, 'USD'))
            
            % Calcul des int�r�ts per�us de l'USD � la p�riode t
            lending_high_foreign = lending_high_usd;
            lending_high_foreign_eop = lending_high_foreign * (1 + ((high_dr(1,i) ./ high_base_yr))); % EOP = End of Period
            lending_high_usd_eop = lending_high_foreign_eop; % EOP = End of Period
            lending_high_usd_eop_prev = 0;
            
            % Calcul des int�r�ts per�us de l'USD � la p�riode (t-1)
            if (k > 2)
                lending_high_usd_prev = lending_high_usd;
                lending_high_foreign_prev = lending_high_usd;
                lending_high_foreign_eop_prev = lending_high_foreign_prev * (1 + ((high_dr_prev(1,i) ./ high_base_yr))); % EOP = End of Period
                lending_high_usd_eop_prev = lending_high_foreign_eop_prev; % EOP = End of Period
            end
        else
            % Calcul des int�r�ts per�us de la currency selectionn�e en t
            % � l'instant t
            lending_high_foreign = lending_high_usd * high_fxrates_dcu(1,i);
            lending_high_foreign_eop = lending_high_foreign * (1 + ((high_dr(1,i) ./ high_base_yr))); % EOP = End of Period
            lending_high_usd_eop = high_fxrates_fcu_next(1,i) * lending_high_foreign_eop; % EOP = End of Period

            % Calcul des int�r�ts per�us de la currency selectionn�e en t
            % � l'instant (t-1)
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
            % Initialisation des payoff pour la p�riode t=-1
            total_lending_high_usd_prev = 0;
        else
            total_lending_high_usd_prev = total_lending_high_usd_prev + lending_high_interest_usd_prev;
        end
    end
    fprintf('\t\t\t ==== TOTAL: %6.4f $ (Previously: %6.4f $) ====\n', total_lending_high_usd, total_lending_high_usd_prev);     
    
    % Composition du tableau de r�sulat de la strat�gie HML
    % 1�re colonne: Calcul du payoff du carry trade S1 vs S5 en t �
    %               l'instant t
    %               (int�r�ts per�us suite au placement sur S5 - co�t 
    %               d'emprunt de S1)
    % 2�me colonne: somme cumul�e des payoffs de la strat�gie HML
    % 3�me colonne: taux de rendements de la p�riode 
    % 4��e colonne: Calcul du payoff du carry trade S1 vs S5 en t �
    %               l'instant t-1
    %               (int�r�ts per�us suite au placement sur S5 - co�t
    %               d'emprunt de S1) : utile pour la strat�gie HML Momentum
    pf_HML(k, 1) = total_lending_high_usd - total_borrowing_low_cost_usd;
    pf_HML(k, 2) = pf_HML(k-1, 2) + pf_HML(k, 1);
    pf_HML(k, 3) = pf_HML(k, 1) / pf_HML(k-1, 2);
    pf_HML(k, 4) = total_lending_high_usd_prev - total_borrowing_low_cost_usd_prev;
end


%% Strat�gie de couverture Momentum High Minus Low (HML)
% Le tablea de r�sulat de la strat�gie HML est compl�t�e de 2 nouvelles
% colonnes pour les r�sultats du Momentum
% 5�me colonne: calcul du payoff de la strat�gie HML Momentum
% 6�me colonne: somme cumul�e des payoffs consolid�s de la strat�gie HML
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

%% Strat�gie de couverture Momentum Equally-Weighted
% Le tableau de r�sultat de la strat�gie EW est compl�t�e de 2 nouvelles
% colonnes pour les r�sultats du Momentum
% 1�re colonne: consolidation des payoffs de carry trade individuels
% 2�me colonne: somme cumul�e des payoffs consolid�s de la strat�gie EW Mom
pf_EW(1, 5) = 0;
[line, ~, nb_cur] = size(strategie_EW);
for i=2:line,
    total_EW_mom = 0;
    
    % Parcours de chaque devise contre l'USD
    % Zt_prev correspond au payoff du carry trade effectu� en t-1
    % Zt correspond au payoff du carry trade effectu� en t
    for j=1:nb_cur,
        Zt_prev = strategie_EW((i-1), 1, j);
        Zt = strategie_EW(i, 1, j);
        
        % V�rification des cas de figures correspondant � un changement de
        % signe du payoff actuel par prise en compte du signe du payoff
        % pr�c�dent. Si tel est le cas, on consid�re le carry trade inverse
        % que l'on a pris le soin de calculer dans la 2�me colonne de
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

%% Strat�gie de couverture Momentum Equally-Weighted en fonction des n derniers payoffs
% Le tableau de r�sultat de la strat�gie EW est compl�t�e de 3 nouvelles
% colonnes pour les r�sultats du Momentum EW en fonction des n derniers
% payoffs.
% La strat�gie consiste � se couvrir uniquement si le cumul des n derniers
% payoffs est inf�rieur � -1 �cart type des n derni�res observations.
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
% M: Maximum atteint de la somme cumul�e des P&L � l'instant t
% DD: Drowdown courant � l'instant t
% MDD: Maximum Drowdown � l'instant t (Max(DD))
% 3 colonnes pour chaque variable: calcul des 3 MDD pour la strat�gie EW,
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
% M: Maximum atteint de la somme cumul�e des P&L � l'instant t
% DD: Drowdown courant � l'instant t
% MDD: Maximum Drowdown � l'instant t (Max(DD))
% 2 colonnes pour chaque variable: calcul des 2 MDD pour la strat�gie HML,
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

%% R�sultats: Tra�age des graphiques 
fprintf('\n=============================== RESULTS =====================================\n');


figure;
plot(pf_dates, pf_EW(:,2), pf_dates, pf_EW(:,5), pf_dates, pf_EW(:,8), pf_dates, pf_EW(:,2)+pf_EW(:,5), pf_dates, pf_EW(:,2)+pf_EW(:,8));
legend('EW','EW Momentum', 'EW Momentum STD', 'EW couvert Mom', 'EW couvert Mom STD')
datetick('x','keepticks','keeplimits')
title('PnL de la Strat�gie Equally-Weighted');

fprintf('\tMAXIMUM DROWDOWN EW:\n');
fprintf('\t\t- EW\t\t\t\t\t\t: %6.2f %% (atteint le %s)\n', (position_mdd_EW(1,1) - mdd_m_EW(1,1))/mdd_m_EW(1,1)*100, datestr(pf_dates(mdd_date_EW(1,1)), 'dd-mmm-yyyy'));
fprintf('\t\t- EW couverture Momentum\t: %6.2f %% (atteint le %s)\n', (position_mdd_EW(1,2) - mdd_m_EW(1,2))/mdd_m_EW(1,2)*100, datestr(pf_dates(mdd_date_EW(1,2)), 'dd-mmm-yyyy'));
fprintf('\t\t- EW couverture Momentum Std: %6.2f %% (atteint le %s)\n', (position_mdd_EW(1,3) - mdd_m_EW(1,3))/mdd_m_EW(1,3)*100, datestr(pf_dates(mdd_date_EW(1,3)), 'dd-mmm-yyyy'));

figure;
plot(pf_dates, pf_HML(:,2), pf_dates, pf_HML(:,6), pf_dates,  pf_HML(:,6) + pf_HML(:,2));
legend('HML','HML Momentum', 'HML couvert Mom');
datetick('x','keepticks','keeplimits');
title('PnL de la Strat�gie HML');

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
        